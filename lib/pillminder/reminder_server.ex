defmodule Pillminder.ReminderServer do
  require Logger
  alias Pillminder.RunInterval

  use GenServer

  @type remind_func :: (() -> any)
  @type state :: %{
          remind_func: remind_func,
          task_supervisor: pid(),
          timer: :timer.tref() | :no_timer
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
      {:ok, %{remind_func: remind_func, timer: :no_timer, task_supervisor: supervisor_pid}}
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
    send_reminder_fn = fn ->
      # We want to time out the call once our next interval hits
      __MODULE__.send_reminder(timeout: interval, server_name: destination)
    end

    make_interval_timer = fn -> RunInterval.apply_interval(interval, send_reminder_fn) end

    case add_timer_to_state(state, make_interval_timer) do
      {:ok, updated_state} when send_strategy == :send_immediately ->
        # Now that we've scheduled the timer, immediately kick off the requested call (which won't be able)
        # to complete at least until after we return
        # TODO: I don't like that this is fire and forget
        kick_off_immediate_send(state.task_supervisor, send_reminder_fn)

        {:reply, :ok, updated_state}

      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      err = {:error, _reason} ->
        {:reply, err, state}
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

        {:error, :ignore}

      {:error, reason} ->
        Logger.error("Failed to start send-immediate task: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec add_timer_to_state(
          state :: state,
          make_timer :: (() -> {:ok, :timer.tref()} | {:error, any()})
        ) ::
          {:ok, state} | {:error, :already_timing | any()}
  defp add_timer_to_state(state, make_timer) do
    with :ok <- ensure_no_timer_in_state(state),
         {:ok, timer_ref} <- make_timer.() do
      {:ok, Map.put(state, :timer, timer_ref)}
    else
      err = {:error, _reason} -> err
    end
  end

  defp ensure_no_timer_in_state(state) do
    case state.timer do
      :no_timer -> :ok
      _ -> {:error, :already_timing}
    end
  end

  @spec cancel_timer(state) :: {:ok, state} | {:error, :no_timer | any}
  defp cancel_timer(state) do
    with {:ok, timer_ref} <- get_timer_from_state(state),
         {:ok, _, next_state} <- remove_timer_from_state(state),
         :ok <- RunInterval.cancel(timer_ref) do
      {:ok, next_state}
    else
      err -> err
    end
  end

  defp get_timer_from_state(%{timer: :no_timer}) do
    {:error, :no_timer}
  end

  defp get_timer_from_state(state) do
    {:ok, state.timer}
  end

  @spec remove_timer_from_state(state) ::
          {:ok, :timer.tref(), state} | {:error, :no_timer}
  defp remove_timer_from_state(state) do
    case state.timer do
      :no_timer ->
        {:error, :no_timer}

      _ ->
        {timer_ref, new_state} = Map.pop(state, :timer)
        {:ok, timer_ref, new_state}
    end
  end
end
