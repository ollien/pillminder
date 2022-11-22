defmodule Pillminder.ReminderServer do
  require Logger
  alias Pillminder.RunInterval

  use GenServer

  @type remind_func :: (() -> any)
  @type state :: %{
          remind_func: remind_func,
          task_supervisor: pid(),
          timer_agent: pid() | :no_timer
        }

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
  @spec init(remind_func) :: {:ok, state}
  def init(remind_func) do
    with {:ok, supervisor_pid} <- Task.Supervisor.start_link() do
      {:ok, %{remind_func: remind_func, timer_agent: :no_timer, task_supervisor: supervisor_pid}}
    else
      {:error, err} -> {:stop, err}
    end
  end

  @impl true
  @spec handle_call(:remind, {pid, term}, state) :: {:reply, {:ok, any} | {:error, any}, state}
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
          {:setup_reminder, non_neg_integer, GenServer.server(),
           :send_immediately | :wait_until_interval},
          {pid, term},
          state
        ) ::
          {:reply, :ok, state}
          | {:reply, {:error, :already_timing | any}, state}
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

  @spec handle_call(:dismiss, {pid, term}, state) ::
          {:reply, :ok | {:error, :no_timer | any}, state}
  def handle_call(:dismiss, _from, state) do
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
      :send_immediately | :wait_until_interval,
      state()
    ) :: {:ok, state()},
    {{:error, any()}, state()}
  )
  defp setup_interval_reminder(interval, destination, send_strategy, state) do
    send_reminder_fn = fn ->
      # We want to time out the call once our next interval hits
      __MODULE__.send_reminder(timeout: interval, server_name: destination)
    end

    with {:ok, timer_agent_pid} <-
           make_reminder_timer(state.task_supervisor, interval, send_reminder_fn),
         Process.link(timer_agent_pid),
         {:ok, updated_state} <- add_timer_to_state(state, timer_agent_pid),
         :ok <-
           perform_send_strategy_tasks(send_strategy, state.task_supervisor, send_reminder_fn) do
      # Now that we've brought everything online, we can unlink so our task can safely terminate
      Process.unlink(timer_agent_pid)
      {:ok, updated_state}
    else
      err = {:error, _reason} ->
        {err, state}
    end
  end

  @spec make_reminder_timer(pid(), number(), (() -> any())) ::
          {:ok, pid()} | {:error, {:spawn_interval, any()}}
  defp make_reminder_timer(supervisor, interval, send_reminder_fn) do
    make_timer_fn = fn ->
      case RunInterval.apply_interval(interval, send_reminder_fn) do
        {:ok, timer_ref} -> timer_ref
        {:error, err} -> {:error, {:reminder_build_failed, err}}
      end
    end

    with {:ok, timer_agent} <- DynamicSupervisor.start_child(supervisor, {Agent, make_timer_fn}) do
      # From the Agent docs, start_link will not return until the init function has returned, so we are guaranteed
      # to have this value
      case Agent.get(timer_agent, & &1) do
        err = {:error, _reason} ->
          # Kill the agent so that it isn't hanging around in the supervisor with an empty state
          Agent.stop(timer_agent)
          err

        _timer_ref ->
          {:ok, timer_agent}
      end
    else
      err -> {:error, {:spawn_interval, err}}
    end
  end

  @spec perform_send_strategy_tasks(:send_immediately, pid(), (() -> any())) ::
          :ok | {:error, any()}
  defp perform_send_strategy_tasks(:send_immediately, supervisor, send_reminder_fn) do
    kick_off_immediate_send(supervisor, send_reminder_fn)
  end

  @spec perform_send_strategy_tasks(:wait_until_interval, pid(), (() -> any())) ::
          :ok | {:error, any()}
  defp perform_send_strategy_tasks(:wait_until_interval, _supervisor, _send_reminder_fn) do
    :ok
  end

  @spec kick_off_immediate_send(pid(), (() -> any())) :: :ok | {:error, any()}
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

        {:error, :task_ignored}

      {:error, reason} ->
        Logger.error("Failed to start send-immediate task: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec add_timer_to_state(state :: state, timer_agent :: pid()) ::
          {:ok, state} | {:error, :already_timing | any()}
  defp add_timer_to_state(state, timer_agent) do
    case state.timer_agent do
      :no_timer -> {:ok, Map.put(state, :timer_agent, timer_agent)}
      _ -> {:error, :already_timing}
    end
  end

  @spec cancel_timer(state) :: {:ok, state} | {:error, :no_timer | any}
  defp cancel_timer(state) do
    with {:ok, timer_ref, next_state} <- remove_timer_from_state(state),
         :ok <- RunInterval.cancel(timer_ref) do
      {:ok, next_state}
    else
      err -> err
    end
  end

  @spec remove_timer_from_state(state) ::
          {:ok, :timer.tref(), state} | {:error, :no_timer}
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
    value = Agent.get(agent, & &1)
    Agent.stop(agent)

    value
  end
end
