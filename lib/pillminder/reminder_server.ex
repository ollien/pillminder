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

  @spec send_reminder_on_interval(non_neg_integer | :infinity) :: {:ok, uuid} | {:error, any}
  def send_reminder_on_interval(interval) do
    GenServer.call(__MODULE__, {:setup_reminder, interval})
  end

  def dismiss_reminder(timer_id) do
    GenServer.call(__MODULE__, {:dismiss, timer_id})
  end

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
    setup_res =
      RunInterval.apply_interval(interval, fn ->
        # We want to time out the call once our next interval hits
        __MODULE__.send_reminder(interval)
      end)

    case setup_res do
      {:ok, timer_ref} ->
        {timer_id, updated_state} = add_timer_to_state(state, timer_ref)
        {:reply, {:ok, timer_id}, updated_state}

      {:error, err} ->
        {:reply, {:error, err}, state}
    end
  end

  @spec handle_call({:dismiss, uuid}, {pid, term}, state) ::
          {:reply, :ok | {:error, :no_timer | any}, state}
  def handle_call({:dismiss, timer_id}, _from, state) do
    case state.timers[timer_id] do
      nil ->
        {:reply, {:error, :no_timer}, state}

      %{timer_ref: timer_ref} ->
        next_state = remove_timer_from_state(state, timer_id)

        case :timer.cancel(timer_ref) do
          {:ok, :cancel} -> {:reply, :ok, next_state}
          {:error, err} -> {:reply, {:error, err}, next_state}
        end
    end

    {:reply, :ok, state}
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

  @spec remove_timer_from_state(state, uuid) :: state
  defp remove_timer_from_state(state, timer_id) do
    {_, new_state} = pop_in(state, [:timers, timer_id])
    new_state
  end
end
