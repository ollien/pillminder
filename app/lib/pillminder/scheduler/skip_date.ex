defmodule Pillminder.Scheduler.SkipDate do
  @moduledoc """
  Stores state related to whether or not a date should be skipped for a timer.
  """
  use GenServer

  alias Pillminder.Scheduler.ScheduledReminder
  alias Pillminder.Util

  @type clock_source :: (() -> DateTime.t())
  @type skip_entry :: Date.t()
  @type opts :: [clock_source: clock_source()]

  defmodule State do
    @enforce_keys :reminders
    defstruct [:reminders, :clock_source, skipped_dates: %{}]

    @type t() :: %__MODULE__{
            reminders: [ScheduledReminder.t()],
            clock_source: Pillminder.Scheduler.clock_source(),
            skipped_dates: %{String.t() => Date.t()}
          }
  end

  @spec start_link({[ScheduledReminder.t()]}) :: GenServer.on_start()
  def start_link({reminders}) do
    start_link({reminders, []})
  end

  @spec start_link({[ScheduledReminder.t()], opts}) :: GenServer.on_start()
  def start_link({reminders, opts}) do
    GenServer.start_link(__MODULE__, {reminders, Keyword.get(opts, :clock_source)},
      name: __MODULE__
    )
  end

  @spec init({[ScheduledReminder.t()], clock_source() | nil}) :: {:ok, State.t()}
  def init({reminders, clock_source}) do
    initial_state = %State{
      reminders: reminders,
      clock_source: clock_source
    }

    {:ok, initial_state}
  end

  @doc """
    The same as `skip_date/2`, but uses the current date in the given timer's timezone.
  """
  @spec skip_date(String.t()) :: :ok | {:error, :no_such_timer}
  def skip_date(timer) do
    GenServer.call(__MODULE__, {:skip_date, timer})
  end

  @doc """
  Skip the given date for timer. This is intended to only handle the skipping
  of a single date. With that in mind, If a date is already stored to be
  skipped, it will be *REPLACED*, and `is_skipped/2` will return false for it.
  """
  @spec skip_date(String.t(), Date.t()) :: :ok | {:error, :no_such_timer}
  def skip_date(timer, date) do
    GenServer.call(__MODULE__, {:skip_date, timer, date})
  end

  @doc """
  Check if the given date is skipped for the given timer
  """
  @spec is_skipped(String.t(), Date.t()) :: boolean
  def is_skipped(timer, date) do
    GenServer.call(__MODULE__, {:is_skipped, timer, date})
  end

  @spec handle_call({:skip_date, String.t()}, GenServer.from(), State.t()) ::
          {:reply, :ok | {:error, :no_such_timer}, State.t()}
  def handle_call({:skip_date, timer_id}, _from, state) do
    reminder = find_reminder(state.reminders, timer_id)

    case add_current_date_to_state(state, reminder) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, :no_such_timer} -> {:reply, {:error, :no_such_timer}, state}
    end
  end

  @spec handle_call({:skip_date, String.t(), Date.t()}, GenServer.from(), State.t()) ::
          {:reply, :ok | {:error, :no_such_timer}, State.t()}
  def handle_call({:skip_date, timer_id, date}, _from, state) do
    case find_reminder(state.reminders, timer_id) do
      nil ->
        {:reply, {:error, :no_such_timer}, state}

      _ ->
        new_state = add_skip_date_to_state(state, timer_id, date)

        {:reply, :ok, new_state}
    end
  end

  @spec handle_call({:is_skipped, String.t(), Date.t()}, GenServer.from(), State.t()) ::
          {:reply, boolean, State.t()}
  def handle_call({:is_skipped, timer_id, date}, _from, state) do
    is_skipped = Map.get(state.skipped_dates, timer_id) == date

    {:reply, is_skipped, state}
  end

  @spec find_reminder([ScheduledReminder.t()], String.t()) :: ScheduledReminder.t() | nil
  defp find_reminder(reminders, timer_id) do
    Enum.find(reminders, fn reminder -> reminder.id == timer_id end)
  end

  @spec add_current_date_to_state(State.t(), ScheduledReminder.t()) ::
          {:ok, State.t()} | {:error, :no_such_timer}
  defp add_current_date_to_state(_state, nil) do
    {:error, :no_such_timer}
  end

  defp add_current_date_to_state(state, reminder) do
    now =
      case state.clock_source do
        nil -> Util.Time.now!(reminder.time_zone)
        clock_source -> clock_source.()
      end

    today = DateTime.to_date(now)
    new_state = add_skip_date_to_state(state, reminder.id, today)
    {:ok, new_state}
  end

  @spec add_skip_date_to_state(State.t(), String.t(), Date.t()) :: State.t()
  defp add_skip_date_to_state(state, timer, date) do
    put_in(state.skipped_dates[timer], date)
  end
end
