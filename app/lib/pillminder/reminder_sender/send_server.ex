defmodule Pillminder.ReminderSender.SendServer do
  @moduledoc """
  The SendServer handles sending medication reminders evenly spaced reminders, such as every few minutes.
  This is intended to handle a single user's reminders and the coordinating management of the associated timers.
  In a multi-user setup, there will be more than one SendServer.
  """

  require Logger
  alias Pillminder.ReminderSender.TimerManager

  use GenServer

  @type clock_source :: (-> DateTime.t())
  @type remind_func :: (-> any())
  @type stop_func :: (-> boolean())
  @type send_strategy :: :send_immediately | :wait_until_interval
  @type send_server_opts :: [
          sender_id: String.t(),
          server_opts: GenServer.options()
        ]

  defmodule State do
    @enforce_keys [:remind_func, :task_supervisor, :sender_id, :clock_source]
    defstruct [:remind_func, :task_supervisor, :sender_id, :clock_source]

    @type t :: %__MODULE__{
            remind_func: Pillminder.ReminderSender.SendServer.remind_func(),
            sender_id: String.t(),
            task_supervisor: Supervisor.supervisor(),
            clock_source: Pillminder.ReminderSender.SendServer.clock_source()
          }
  end

  @doc """
  Start a SendServer that is linked to the current pid, which wil send reminders to the given `remind_func`. The
  given Task.Supervisor reference will be used for one-off tasks being run during this server's lifetime.

  The `opts` keyword list is used to configure custom SendServer options, which are as follows

  - sender_id: A human-readable identifier for this server. If not, it is inferred from `server_opts[:name]`
  - server_opts: Used to provide custom configuration for GenServer. See `GenServer` for more details
  on these options.
  """

  @spec start_link(
          {remind_func, Supervisor.supervisor(), clock_source(), send_server_opts}
          | {remind_func, Supervisor.supervisor(), clock_source()}
        ) ::
          {:ok, pid} | {:error, any} | :ignore
  def start_link({remind_func, task_supervisor, clock_source})
      when not is_list(task_supervisor) do
    start_link({remind_func, task_supervisor, clock_source, []})
  end

  def start_link({remind_func, task_supervisor, clock_source, opts}) when is_list(opts) do
    server_opts = Keyword.get(opts, :server_opts, [])
    full_opts = Keyword.put_new(server_opts, :name, __MODULE__)

    # A sender id is used to give a readable name in logs; if not included, we'll just use the registered name.
    # Via tuples are kind of hard to read so I don't really want to use them
    sender_id =
      Keyword.get(opts, :sender_id, Keyword.get(server_opts, :name, __MODULE__)) |> stringify_id()

    GenServer.start_link(
      __MODULE__,
      {remind_func, task_supervisor, sender_id, clock_source},
      full_opts
    )
  end

  @doc """
    Call the reminder every interval milliseconds. An error is returned if the calling interval could not
    be set up; the remind_func will not be called if this happens.
  """
  @spec send_reminder_on_interval(non_neg_integer | :infinity,
          server_name: GenServer.server(),
          send_immediately: boolean(),
          stop_time: DateTime.t()
        ) ::
          :ok | {:error, :already_timing | any}
  def send_reminder_on_interval(interval, opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)

    send_strategy =
      if Keyword.get(opts, :send_immediately, false) do
        :send_immediately
      else
        :wait_until_interval
      end

    stop_time = Keyword.get(opts, :stop_time)

    GenServer.call(
      destination,
      {:setup_reminder, interval, destination, send_strategy, stop_time}
    )
  end

  @doc """
    Call the reminder every interval milliseconds. An error is returned if there is no timer currently running,
    or the timer failed to cancel.
  """
  @spec dismiss(server_name: GenServer.server()) :: :ok | {:error, :not_timing | any}
  def dismiss(opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(destination, :dismiss)
  end

  @spec snooze(non_neg_integer, keyword) :: :ok | {:error, :not_timing}
  def snooze(snooze_time, opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(destination, {:snooze, snooze_time})
  end

  @doc """
    Call the reminder func, with a given timeout in milliseconds. NOTE: the "ok" variant here is used to indicate
    that the function was successfully called. If your function returns an :error tuple, for instance, you may
    receive {:ok, {:error, some_error}}
  """
  @spec send_reminder(timeout: non_neg_integer | :infinity, server_name: GenServer.server()) ::
          {:ok, any} | {:error, any}
  def send_reminder(opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)
    timeout = Keyword.get(opts, :timeout, 5000)
    GenServer.call(destination, :remind, timeout)
  end

  @impl true
  @spec init({remind_func, Supervisor.supervisor(), String.t(), clock_source()}) ::
          {:ok, State.t()}
  def init({remind_func, task_supervisor, sender_id, clock_source}) do
    Logger.metadata(sender_id: sender_id)

    initial_state = %State{
      sender_id: sender_id,
      remind_func: remind_func,
      task_supervisor: task_supervisor,
      clock_source: clock_source
    }

    {:ok, initial_state}
  end

  @impl true
  @spec handle_call(:remind, {pid, term}, State.t()) ::
          {:reply, {:ok, any} | {:error, any}, State.t()}
  def handle_call(:remind, _from, state) do
    logger_metadata = Logger.metadata()

    task =
      GenRetry.Task.Supervisor.async_nolink(
        state.task_supervisor,
        fn ->
          # Inherit the metadata from the parent process
          Logger.metadata(logger_metadata)

          state.remind_func.()
        end,
        retries: 4,
        delay: 250
      )

    case Task.yield(task, :infinity) do
      {:exit, :normal} ->
        {:reply, {:ok, nil}, state}

      {:ok, ret} ->
        {:reply, {:ok, ret}, state}

      {:exit, reason} ->
        {:reply, {:error, {:exit, reason}}, state}
    end
  end

  @spec handle_call(
          {:setup_reminder, non_neg_integer, GenServer.server(), send_strategy(),
           DateTime.t() | nil},
          {pid, term},
          State.t()
        ) ::
          {:reply, :ok, State.t()}
          | {:reply, {:error, :already_timing | any}, State.t()}
  def handle_call(
        {:setup_reminder, interval, destination, send_strategy, maybe_stop_time},
        _from,
        state
      ) do
    case setup_interval_reminder(interval, destination, send_strategy, maybe_stop_time, state) do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @spec handle_call(:dismiss, {pid, term}, State.t()) ::
          {:reply, :ok | {:error, :not_timing | any}, State.t()}
  def handle_call(:dismiss, _from, state) do
    case TimerManager.cancel_timer(state.sender_id) do
      :ok -> {:reply, :ok, state}
      {:error, err} -> {:reply, {:error, err}, state}
    end
  end

  @spec handle_call(:snooze, {pid, term}, State.t()) ::
          {:reply, :ok | {:error, :not_timing | any}, State.t()}
  def handle_call({:snooze, snooze_ms}, _from, state) do
    snooze_minutes = fn ->
      Timex.Duration.from_milliseconds(snooze_ms)
      |> Timex.Duration.to_minutes()
      |> (&:io_lib.format("~.2f", [&1])).()
    end

    Logger.debug("Snoozing timer for #{snooze_minutes.()} minutes")

    case TimerManager.snooze_timer(state.sender_id, snooze_ms) do
      :ok -> {:reply, :ok, state}
      {:error, :not_timing} -> {:reply, {:error, :not_timing}, state}
    end
  end

  @spec setup_interval_reminder(
          number(),
          GenServer.server(),
          send_strategy(),
          DateTime.t() | nil,
          State.t()
        ) :: :ok | {:error, any()}
  defp setup_interval_reminder(
         interval,
         reminder_destination,
         send_strategy,
         maybe_stop_time,
         state
       ) do
    send_reminder_fn = fn ->
      # We want to time out the call once our next interval hits
      GenServer.call(reminder_destination, :remind, interval)
    end

    stop_fn = fn ->
      now = state.clock_source.()

      case maybe_stop_time do
        nil -> false
        stop_time -> not Timex.before?(now, stop_time)
      end
    end

    with :ok <- make_reminder_timer(state.sender_id, interval, send_reminder_fn, stop_fn),
         :ok <-
           perform_send_strategy_tasks(send_strategy, state.task_supervisor, send_reminder_fn) do
      Logger.debug(
        "Reminder timer for interval #{interval} (and stop time of #{maybe_stop_time}) has been stored and begun"
      )

      :ok
    else
      err = {:error, _reason} ->
        # It doesn't matter if this fails; it can only fail if the timer doesn't exist, which is fine.
        TimerManager.cancel_timer(state.sender_id)
        err
    end
  end

  @spec make_reminder_timer(String.t(), number(), remind_func(), stop_func()) ::
          :ok | {:error, :already_timing | {:spawn_reminder_timer, any()}}
  defp make_reminder_timer(id, interval, send_reminder_fn, stop_fn) do
    case TimerManager.start_reminder_timer(id, interval, send_reminder_fn, stop_fn) do
      :ok ->
        Logger.debug("Made reminder timer with interval #{interval}")
        :ok

      err = {:error, :already_timing} ->
        err

      {:error, err} ->
        {:error, {:spawn_reminder_timer, err}}
    end
  end

  @spec perform_send_strategy_tasks(:send_immediately, pid(), remind_func()) ::
          :ok | {:error, any()}
  defp perform_send_strategy_tasks(:send_immediately, supervisor, send_reminder_fn) do
    kick_off_immediate_send(supervisor, send_reminder_fn)
  end

  @spec perform_send_strategy_tasks(:wait_until_interval, pid(), remind_func()) ::
          :ok | {:error, any()}
  defp perform_send_strategy_tasks(:wait_until_interval, _supervisor, _send_reminder_fn) do
    :ok
  end

  @spec kick_off_immediate_send(pid(), remind_func()) :: :ok | {:error, any()}
  defp kick_off_immediate_send(supervisor, send_reminder_fn) do
    case Task.Supervisor.start_child(supervisor, send_reminder_fn) do
      {:ok, _} ->
        Logger.debug("Started 'send_immediately' task")
        :ok

      {:ok, _, _} ->
        Logger.debug("Started 'send_immediately' task")
        :ok

      :ignore ->
        Logger.error(
          "Failed to start send-immediate task, supervisor was asked to ignore the task"
        )

        {:error, :ignore}

      {:error, reason} ->
        Logger.error("Failed to start send-immediate task: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp stringify_id(name) when is_atom(name) do
    Atom.to_string(name)
  end

  defp stringify_id(name) when is_binary(name) do
    name
  end

  defp stringify_id(name) do
    inspect(name)
  end
end
