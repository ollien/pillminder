defmodule Pillminder.ReminderServer do
  alias Pillminder.RunInterval

  use GenServer

  @type remind_func :: (() -> any)
  @type state :: %{
          remind_func: remind_func,
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
  @spec send_reminder_on_interval(non_neg_integer | :infinity, server_name: GenServer.name()) ::
          :ok | {:error, :already_timing | any}
  def send_reminder_on_interval(interval, opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(destination, {:setup_reminder, interval, destination})
  end

  @doc """
    Call the reminder every interval milliseconds. An error is returned if there is no timer currently running,
    or the timer failed to cancel.
  """
  @spec dismiss(server_name: GenServer.name()) :: :ok | {:error, :no_timer | any}
  def dismiss(opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)
    GenServer.call(destination, :dismiss)
  end

  @doc """
    Cal the reminder func, with a given timeout in milliseconds
  """
  @spec send_reminder(timeout: non_neg_integer | :infinity, server_name: GenServer.name()) :: any
  def send_reminder(opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)
    timeout = Keyword.get(opts, :timeout, 5000)
    GenServer.call(destination, :remind, timeout)
  end

  @impl true
  @spec init(remind_func) :: {:ok, state}
  def init(remind_func) do
    {:ok, %{remind_func: remind_func, timer: :no_timer}}
  end

  @impl true
  @spec handle_call(:remind, {pid, term}, state) :: {:reply, any, state}
  def handle_call(:remind, _from, state) do
    ret = state.remind_func.()
    {:reply, ret, state}
  end

  @spec handle_call({:setup_reminder, non_neg_integer, GenServer.name()}, {pid, term}, state) ::
          {:reply, :ok, state}
          | {:reply, {:error, :already_timing | any}, state}
  def handle_call({:setup_reminder, interval, destination}, _from, state) do
    send_reminder_fn = fn ->
      # We want to time out the call once our next interval hits
      __MODULE__.send_reminder(timeout: interval, server_name: destination)
    end

    with {:ok, timer_ref} <- RunInterval.apply_interval(interval, send_reminder_fn),
         {:ok, updated_state} <- add_timer_to_state(state, timer_ref) do
      {:reply, :ok, updated_state}
    else
      err -> {:reply, err, state}
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

  @spec add_timer_to_state(state, :timer.tref()) :: {:ok, state} | {:error, :already_timing}
  defp add_timer_to_state(state, timer) do
    case state.timer do
      :no_timer -> {:ok, Map.put(state, :timer, timer)}
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
