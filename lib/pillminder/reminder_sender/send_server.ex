defmodule Pillminder.ReminderSender.SendServer do
  @moduledoc """
  The SendServer handles sending medication reminders evenly spaced reminders, such as every few minutes.
  This is intended to handle a single user's reminders; in a multi-user setup, there will be more than one
  SendServer.
  """

  require Logger
  alias Pillminder.ReminderSender.TimerManager

  use GenServer

  @type remind_func :: (() -> any)
  @type send_strategy :: :send_immediately | :wait_until_interval
  @type send_server_opts :: [sender_id: String.t(), server_opts: GenServer.options()]

  defmodule State do
    @enforce_keys [:remind_func, :task_supervisor, :sender_id]
    defstruct [:remind_func, :task_supervisor, :sender_id, timer_agent: :no_timer]

    @type t :: %__MODULE__{
            remind_func: Pillminder.ReminderSender.SendServer.remind_func(),
            sender_id: String.t(),
            task_supervisor: pid()
          }
  end

  def start_link({remind_func}) do
    start_link({remind_func, []})
  end

  @doc """
  Start a SendServer that is linked to the current pid, which wil send reminders to the given `remind_func`
  The `opts` keyword list is used to configure custom SendServer options, which are as follows

  - sender_id: A human-readable identifier for this server. If not, it is inferred from `server_opts[:name]`
  - server_opts: Used to provide custom configuration for GenServer. See `GenServer` for more details
  on these options.
  """
  @spec start_link({remind_func, send_server_opts}) ::
          {:ok, pid} | {:error, any} | :ignore
  def start_link({remind_func, opts}) do
    server_opts = Keyword.get(opts, :server_opts, [])
    full_opts = Keyword.put_new(server_opts, :name, __MODULE__)

    # A sender id is used to give a readable name in logs; if not included, we'll just use the registered name.
    # Via tuples are kind of hard to read so I don't really want to use them
    sender_id =
      Keyword.get(opts, :sender_id, Keyword.get(server_opts, :name, __MODULE__)) |> stringify_id()

    GenServer.start_link(__MODULE__, {remind_func, sender_id}, full_opts)
  end

  @doc """
    Call the reminder every interval milliseconds. An error is returned if the calling interval could not
    be set up; the remind_func will not be called if this happens.
  """
  @spec send_reminder_on_interval(non_neg_integer | :infinity,
          server_name: GenServer.server(),
          send_immediately: boolean
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

    GenServer.call(destination, {:setup_reminder, interval, destination, send_strategy})
  end

  @doc """
    Call the reminder every interval milliseconds. An error is returned if there is no timer currently running,
    or the timer failed to cancel.
  """
  @spec dismiss(server_name: GenServer.server()) :: :ok | {:error, :no_timer | any}
  def dismiss(opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(destination, :dismiss)
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
  @spec init({remind_func, String.t()}) :: {:ok, State.t()}
  def init({remind_func, sender_id}) do
    Logger.metadata(sender_id: sender_id)

    case Task.Supervisor.start_link() do
      {:ok, supervisor_pid} ->
        initial_state = %State{
          sender_id: sender_id,
          remind_func: remind_func,
          task_supervisor: supervisor_pid
        }

        {:ok, initial_state}

      {:error, err} ->
        {:stop, err}
    end
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
          {:setup_reminder, non_neg_integer, GenServer.server(), send_strategy()},
          {pid, term},
          State.t()
        ) ::
          {:reply, :ok, State.t()}
          | {:reply, {:error, :already_timing | any}, State.t()}
  def handle_call({:setup_reminder, interval, destination, send_strategy}, _from, state) do
    logger_metadata = Logger.metadata()

    task =
      Task.Supervisor.async_nolink(
        state.task_supervisor,
        fn ->
          # Inherit the metadata from the parent process
          Logger.metadata(logger_metadata)

          setup_interval_reminder(interval, destination, send_strategy, state)
        end
      )

    case Task.yield(task, :infinity) do
      {:ok, :ok} ->
        {:reply, :ok, state}

      {:ok, err = {:error, _reason}} ->
        {:reply, err, state}

      {:exit, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @spec handle_call(:dismiss, {pid, term}, State.t()) ::
          {:reply, :ok | {:error, :no_timer | any}, State.t()}
  def handle_call(:dismiss, _from, state) do
    Logger.debug("Dismissing timer")

    case TimerManager.cancel_timer(state.sender_id) do
      :ok -> {:reply, :ok, state}
      {:error, err} -> {:reply, {:error, err}, state}
    end
  end

  @spec setup_interval_reminder(
          number(),
          GenServer.server(),
          send_strategy(),
          State.t()
        ) :: :ok | {:error, any()}
  defp setup_interval_reminder(interval, reminder_destination, send_strategy, state) do
    send_reminder_fn = fn ->
      # We want to time out the call once our next interval hits
      GenServer.call(reminder_destination, :remind, interval)
    end

    with {:ok, timer_agent_pid} <-
           make_timer_agent(state.sender_id, interval, send_reminder_fn),
         Process.link(timer_agent_pid),
         :ok <-
           perform_send_strategy_tasks(send_strategy, state.task_supervisor, send_reminder_fn) do
      # Now that we've brought everything online, we can unlink so our task can safely terminate
      Process.unlink(timer_agent_pid)
      Logger.debug("Reminder timer for interval #{interval} has been stored and begun")
      :ok
    else
      err = {:error, _reason} -> err
    end
  end

  @spec make_timer_agent(String.t(), number(), remind_func()) ::
          {:ok, pid()} | {:error, :already_timing | {:spawn_reminder_timer, any()}}
  defp make_timer_agent(id, interval, send_reminder_fn) do
    case TimerManager.start_timer_agent(id, interval, send_reminder_fn) do
      {:ok, timer_agent} ->
        Logger.debug("Made agent for timer with interval #{interval}")
        {:ok, timer_agent}

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
