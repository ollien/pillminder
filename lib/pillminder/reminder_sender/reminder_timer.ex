defmodule Pillminder.ReminderSender.ReminderTimer do
  @moduledoc """
  A timer that will periodically remind the user to take their medication, based on a given interval.
  """

  use GenServer

  alias Pillminder.Util.RunInterval

  defmodule State do
    @enforce_keys [:timer, :interval, :remind_func]
    defstruct [:timer, :interval, :remind_func]

    @type t() :: %__MODULE__{
            timer: {:interval_timer | :snoozed_timer, :timer.tref()},
            interval: non_neg_integer(),
            remind_func: (() -> any)
          }
  end

  @doc """
  Start a timer agent, which will call `RunInterval.apply_interval/2` with the given arguments. If {:ok, pid()} is
  returned, the pid is guaranteed to be an agent with an already-running timer ref
  """
  @spec start_link({number(), (() -> any()), GenServer.options()}) ::
          {:ok, pid()} | {:error, any()}
  def start_link({interval, send_reminder_fn}) do
    start_link({interval, send_reminder_fn, []})
  end

  def start_link({interval, send_reminder_fn, opts}) do
    GenServer.start_link(__MODULE__, {interval, send_reminder_fn}, opts)
  end

  @impl true
  @spec init({non_neg_integer, (() -> any)}) :: {:ok, State.t()} | {:stop, any}
  def init({interval, send_reminder_fn}) do
    case make_initial_timer_state(interval, send_reminder_fn) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @doc """
  Stop the timer agent. See `Agent.stop/3` for more details.
  """
  @spec stop(Agent.agent(), atom, non_neg_integer | :infinity) :: any
  def stop(agent, reason \\ :normal, timeout \\ 5000) do
    GenServer.stop(agent, reason, timeout)
  end

  @doc """
  Snooze the current timer
  """
  @spec snooze(GenServer.name(), non_neg_integer) :: :ok
  def snooze(destination, snooze_ms) do
    GenServer.call(destination, {:snooze, snooze_ms, destination})
  end

  @impl true
  def handle_call(
        {:snooze, snooze_ms, unsnooze_destination},
        _from,
        state = %State{timer: {:interval_timer, timer_ref}}
      ) do
    with :ok <- cancel_before_snooze(timer_ref),
         {:ok, timer_ref} <- schedule_unsnooze(unsnooze_destination, snooze_ms) do
      updated_state = Map.put(state, :timer, {:snoozed_timer, timer_ref})
      {:reply, :ok, updated_state}
    else
      # We really can't recover from something like this. We could attempt to reschedule the original interval
      # timer but that would be difficult to deal with (what if that reschedule failed?)
      {:error, reason} -> raise({:snooze_failed, reason})
    end
  end

  @impl true
  def handle_call(
        :unsnooze,
        _from,
        %State{
          timer: {:snoozed_timer, _timer_ref},
          interval: interval,
          remind_func: remind_func
        }
      ) do
    # We really can't recover rom something like this. If this fails, we have neither of our timers running
    # and crashing is the best we can do
    {:ok, state} = reinitialize_after_snooze(interval, remind_func)
    {:reply, :ok, state}
  end

  @spec make_initial_timer_state(number(), (() -> any())) :: {:ok, State.t()} | {:error, any()}
  defp make_initial_timer_state(interval, send_reminder_fn) do
    case RunInterval.apply_interval(interval, send_reminder_fn) do
      {:ok, timer_ref} ->
        state = %State{
          timer: {:interval_timer, timer_ref},
          interval: interval,
          remind_func: send_reminder_fn
        }

        {:ok, state}

      err = {:error, _err} ->
        err
    end
  end

  @spec cancel_before_snooze(:timer.tref()) :: :ok | {:error, any}
  defp cancel_before_snooze(timer_ref) do
    case RunInterval.cancel(timer_ref) do
      :ok -> :ok
      {:error, reason} -> {:error, {:interval_cancel_failed, reason}}
    end
  end

  defp schedule_unsnooze(destination, snooze_ms) do
    schedule_res =
      RunInterval.apply_after(snooze_ms, fn ->
        unsnooze(destination)
      end)

    case schedule_res do
      {:ok, timer_ref} -> {:ok, timer_ref}
      {:error, reason} -> {:error, {:unsnooze_schedule_failed, reason}}
    end
  end

  defp unsnooze(destination) do
    GenServer.call(destination, :unsnooze)
  end

  defp reinitialize_after_snooze(interval, remind_func) do
    case make_initial_timer_state(interval, remind_func) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:error, {:unsnooze_failed, reason}}
    end
  end
end
