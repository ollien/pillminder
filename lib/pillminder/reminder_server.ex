defmodule Pillminder.ReminderServer do
  alias Pillminder.RunInterval

  use GenServer

  @type uuid :: binary()
  @type state :: %{
          remind_func: function,
          timers: %{
            uuid => %{timer_ref: :timer.tref(), snoozed_until: %Time{} | :not_snoozed}
          }
        }

  @spec start_link(function, keyword) :: {:error, any} | {:ok, pid} | {:error, any} | :ignore
  def start_link(remind_func, opts \\ []) do
    full_opts = Keyword.merge([name: __MODULE__], opts)
    GenServer.start_link(__MODULE__, remind_func, full_opts)
  end

  @doc """
    Call the reminder every interval milliseconds. An error is returned if the calling interval could not
    be set up; the remind_func will not be called if this happens.
  """
  @spec send_reminder_on_interval(non_neg_integer | :infinity) :: {:ok, uuid} | {:error, any}
  def send_reminder_on_interval(interval) do
    GenServer.call(__MODULE__, {:setup_reminder, interval})
  end

  @doc """
    Dismiss a reminder from the given timer_id. This will prevent any future calls to the reminder_func
  """
  def dismiss_reminder(timer_id) do
    GenServer.call(__MODULE__, {:dismiss, timer_id})
  end

  @doc """
    Cal the reminder func, with a given timeout in milliseconds
  """
  @spec send_reminder(non_neg_integer | :infinity) :: any
  def send_reminder(timeout \\ 5000) do
    GenServer.call(__MODULE__, :remind, timeout)
  end

  @impl true
  @spec init(function) :: {:ok, state}
  def init(remind_func) do
    {:ok, %{remind_func: remind_func, timers: %{}}}
  end

  @impl true
  @spec handle_call(:remind, {pid, term}, state) :: {:reply, any, state}
  def handle_call(:remind, _from, state) do
    ret = state.remind_func.()
    {:reply, ret, state}
  end

  @impl true
  @spec handle_call({:setup_reminder, non_neg_integer}, {pid, term}, state) ::
          {:reply, {:ok, uuid}, state}
          | {:reply, {:error, any}, state}
  def handle_call({:setup_reminder, interval}, _from, state) do
    send_reminder_fn = fn ->
      # We want to time out the call once our next interval hits
      __MODULE__.send_reminder(interval)
    end

    with {:ok, timer_ref} <- RunInterval.apply_interval(interval, send_reminder_fn),
         {timer_id, updated_state} <- add_timer_to_state(state, timer_ref) do
      {:reply, {:ok, timer_id}, updated_state}
    else
      err -> {:reply, err, state}
    end
  end

  @spec handle_call({:dismiss, uuid}, {pid, term}, state) ::
          {:reply, :ok | {:error, :no_timer | any}, state}
  def handle_call({:dismiss, timer_id}, _from, state) do
    cancel_res = cancel_timer(state, timer_id)

    case cancel_res do
      {:ok, next_state} -> {:reply, :ok, next_state}
      {:error, err} -> {:reply, :error, err}
    end
  end

  @spec add_timer_to_state(state, :timer.tref()) :: {uuid, state}
  defp add_timer_to_state(state, timer) do
    uuid = UUID.uuid4()

    updated_state =
      put_in(state, [:timers, uuid], %{
        snoozed_until: :not_snoozed,
        timer_ref: timer
      })

    {uuid, updated_state}
  end

  @spec cancel_timer(state, uuid) :: {:ok, state} | {:error, :no_timer | any}
  defp cancel_timer(state, timer_id) do
    with {:ok, timer_ref, next_state} <- remove_timer_from_state(state, timer_id),
         :ok <- RunInterval.cancel(timer_ref) do
      {:ok, next_state}
    else
      err -> err
    end
  end

  @spec remove_timer_from_state(state, uuid) ::
          {:ok, :timer.timer_ref(), state} | {:error, :no_timer}
  defp remove_timer_from_state(state, timer_id) do
    {popped, new_state} = pop_in(state, [:timers, timer_id])

    case popped do
      nil -> {:error, :no_timer}
      _ -> {:ok, popped.timer_ref, new_state}
    end
  end
end
