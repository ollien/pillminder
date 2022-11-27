defmodule Pillminder.ReminderSender.SendServer do
  @moduledoc """
  The ReminderSender handles sending mdeication reminders evenly spaced reminders, such as every few minutes.
  This is intended to handle a single user's reminders; in a multi-user setup, there will be more than one
  ReminderSender.
  """

  require Logger
  alias Pillminder.Util.RunInterval
  alias Pillminder.ReminderSender.TimerAgent
  alias Pillminder.ReminderSender.TimerSupervisor

  use GenServer

  @type remind_func :: (() -> any)
  @type send_strategy :: :send_immediately | :wait_until_interval

  defmodule State do
    @enforce_keys [:remind_func, :task_supervisor]
    defstruct [:remind_func, :task_supervisor, timer_agent: :no_timer]

    @type t :: %__MODULE__{
            remind_func: Pillminder.ReminderSender.SendServer.remind_func(),
            task_supervisor: pid(),
            timer_agent: pid() | :no_timer
          }
  end

  def start_link({remind_func}) do
    start_link({remind_func, []})
  end

  @spec start_link({remind_func, GenServer.options()}) ::
          {:ok, pid} | {:error, any} | :ignore
  def start_link({remind_func, opts}) do
    full_opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, remind_func, full_opts)
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
  @spec init(remind_func) :: {:ok, State.t()}
  def init(remind_func) do
    case Task.Supervisor.start_link() do
      {:ok, supervisor_pid} ->
        initial_state = %State{
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
    task =
      GenRetry.Task.Supervisor.async_nolink(state.task_supervisor, state.remind_func, delay: 250)

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
    task =
      Task.Supervisor.async_nolink(
        state.task_supervisor,
        fn -> setup_interval_reminder(interval, destination, send_strategy, state) end
      )

    case Task.yield(task, :infinity) do
      {:ok, {:ok, output_state}} ->
        {:reply, :ok, output_state}

      {:ok, {err = {:error, _reason}, output_state}} ->
        {:reply, err, output_state}

      {:exit, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @spec handle_call(:dismiss, {pid, term}, State.t()) ::
          {:reply, :ok | {:error, :no_timer | any}, State.t()}
  def handle_call(:dismiss, _from, state) do
    # I hate this log but I don't have other identifying info for this
    # TODO: Get some kind of identification into state
    Logger.debug("Dismissing timer")

    cancel_res = cancel_timer(state)

    case cancel_res do
      {:ok, next_state} -> {:reply, :ok, next_state}
      {:error, err} -> {:reply, {:error, err}, state}
    end
  end

  @spec(
    setup_interval_reminder(
      number(),
      GenServer.server(),
      send_strategy(),
      State.t()
    ) :: {:ok, State.t()},
    {{:error, any()}, State.t()}
  )
  defp setup_interval_reminder(interval, destination, send_strategy, state) do
    send_reminder_fn = fn ->
      # We want to time out the call once our next interval hits
      GenServer.call(destination, :remind, interval)
    end

    with {:ok, timer_agent_pid} <-
           make_timer_agent(interval, send_reminder_fn),
         Process.link(timer_agent_pid),
         {:ok, updated_state} <- add_timer_to_state(state, timer_agent_pid),
         :ok <-
           perform_send_strategy_tasks(send_strategy, state.task_supervisor, send_reminder_fn) do
      # Now that we've brought everything online, we can unlink so our task can safely terminate
      Process.unlink(timer_agent_pid)
      Logger.debug("Reminder timer for interval #{interval} has been stored and begun")
      {:ok, updated_state}
    else
      err = {:error, _reason} ->
        {err, state}
    end
  end

  @spec make_timer_agent(number(), remind_func()) ::
          {:ok, pid()} | {:error, {:spawn_reminder_timer, any()}}
  defp make_timer_agent(interval, send_reminder_fn) do
    case TimerSupervisor.start_timer_agent(interval, send_reminder_fn) do
      {:ok, timer_agent} ->
        Logger.debug("Made agent for timer with interval #{interval}")
        {:ok, timer_agent}

      {:error, err} ->
        {:error, {:spawn_reminder_timer, err}}
    end
  end

  @spec add_timer_to_state(state :: State.t(), timer_agent :: pid()) ::
          {:ok, State.t()} | {:error, :already_timing | any()}
  defp add_timer_to_state(state, timer_agent) do
    case state.timer_agent do
      :no_timer -> {:ok, Map.put(state, :timer_agent, timer_agent)}
      _ -> {:error, :already_timing}
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

  @spec cancel_timer(State.t()) :: {:ok, State.t()} | {:error, :no_timer | any}
  defp cancel_timer(state) do
    with {:ok, timer_ref, next_state} <- remove_timer_from_state(state),
         :ok <- cancel_timer_ref(timer_ref) do
      {:ok, next_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec cancel_timer(:timer.tref()) :: :ok | {:error, {:cancel_failed, any()}}
  defp cancel_timer_ref(timer_ref) do
    case RunInterval.cancel(timer_ref) do
      :ok -> :ok
      {:error, reason} -> {:error, {:cancel_failed, reason}}
    end
  end

  @spec remove_timer_from_state(State.t()) ::
          {:ok, :timer.tref(), State.t()} | {:error, :no_timer}
  defp remove_timer_from_state(state) do
    case state.timer_agent do
      :no_timer ->
        {:error, :no_timer}

      _ ->
        {timer_agent, no_timer_state} = Map.pop(state, :timer_agent)
        new_state = Map.put(no_timer_state, :timer_agent, :no_timer)
        timer_ref = extract_and_stop_agent(timer_agent)

        {:ok, timer_ref, new_state}
    end
  end

  defp extract_and_stop_agent(agent) do
    value = TimerAgent.get_value(agent)
    TimerAgent.stop(agent)

    value
  end
end