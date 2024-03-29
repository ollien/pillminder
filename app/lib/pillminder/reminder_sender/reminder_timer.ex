defmodule Pillminder.ReminderSender.ReminderTimer do
  @moduledoc """
  A timer that will periodically remind the user to take their medication, based on a given interval.
  """

  require Logger
  alias Pillminder.Util.RunInterval

  use GenServer

  defmodule State do
    @enforce_keys [:timer, :interval, :remind_func, :task_supervisor]
    defstruct [:timer, :interval, :remind_func, :task_supervisor]

    @type t() :: %__MODULE__{
            timer: {:interval_timer | :snoozed_timer, :timer.tref()},
            interval: non_neg_integer(),
            remind_func: (-> any()),
            task_supervisor: pid()
          }
  end

  @doc """
  Start a timer agent, which will call `RunInterval.apply_interval/2` with the given arguments. If {:ok, pid()} is
  returned, the pid is guaranteed to be an agent with an already-running timer ref
  """
  @spec start_link(
          {id :: any, interval :: non_neg_integer, send_reminder_fun :: (-> any()),
           stop_func :: (-> boolean()), opts :: GenServer.options()}
        ) ::
          {:ok, pid()} | {:error, any()}
  def start_link({id, interval, send_reminder_fn, stop_func}) do
    start_link({id, interval, send_reminder_fn, stop_func, []})
  end

  def start_link({id, interval, send_reminder_fn, stop_func, opts}) do
    GenServer.start_link(__MODULE__, {id, interval, send_reminder_fn, stop_func}, opts)
  end

  @impl true
  @spec init(
          {id :: any(), interval :: non_neg_integer, send_reminder_fn :: (-> any),
           stop_func :: (-> boolean())}
        ) ::
          {:ok, State.t()} | {:stop, any}
  def init({id, interval, send_reminder_fn, stop_func}) do
    Logger.metadata(timer_id: id)

    case make_initial_timer_state(interval, send_reminder_fn, stop_func) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @doc """
  Stop the timer agent. See `GenServer.stop/3` for more details.
  """
  @spec stop(GenServer.server(), atom, non_neg_integer | :infinity) :: :ok
  def stop(server, reason \\ :normal, timeout \\ 5000) do
    GenServer.stop(server, reason, timeout)
  end

  @doc """
  Snooze the current timer fo ra given number of milliseconds..
  """
  @spec snooze(GenServer.name(), non_neg_integer) :: :ok
  def snooze(destination, snooze_ms) do
    GenServer.call(destination, {:snooze, snooze_ms, destination})
  end

  @impl true
  def handle_call(
        {:snooze, snooze_ms, unsnooze_destination},
        _from,
        state = %State{timer: {_timer_type, timer_ref}}
      ) do
    with :ok <- cancel_before_snooze(timer_ref),
         {:ok, timer_ref} <- schedule_unsnooze(unsnooze_destination, snooze_ms) do
      updated_state = Map.put(state, :timer, {:snoozed_timer, timer_ref})
      {:reply, :ok, updated_state}
    else
      # We really can't recover from something like this. We could attempt to reschedule the original interval
      # timer (if we had one!) but that would be difficult to deal with (what if that reschedule failed?)
      {:error, reason} -> raise({:snooze_failed, reason})
    end
  end

  @impl true
  def handle_call(
        :unsnooze,
        _from,
        state = %State{
          timer: {:snoozed_timer, _timer_ref}
        }
      ) do
    # Immediately try to kick off again; this is a fire and forget. What matters most is we start the timer again
    send_initial_unsnooze_message(state.task_supervisor, state.remind_func)

    # If this fails, we have neither of our timers running and crashing is the best we can do
    {:ok, state} = reinitialize_after_snooze(state)
    {:reply, :ok, state}
  end

  @spec make_initial_timer_state(number(), (-> any()), (-> boolean())) ::
          {:ok, State.t()} | {:error, any()}
  defp make_initial_timer_state(interval, send_reminder_fn, stop_fn) do
    remind_func = make_interval_action(send_reminder_fn, stop_fn)

    with {:ok, supervisor_pid} <- Task.Supervisor.start_link(),
         {:ok, timer_ref} <-
           RunInterval.apply_interval(interval, remind_func) do
      state = %State{
        timer: {:interval_timer, timer_ref},
        interval: interval,
        remind_func: remind_func,
        task_supervisor: supervisor_pid
      }

      {:ok, state}
    else
      err = {:error, _err} ->
        err
    end
  end

  # Wrap the reminder func with stop_fn so that we handle stop this timer as needed
  @spec make_interval_action((-> any()), (-> boolean())) :: (-> any())
  defp make_interval_action(send_reminder_fn, stop_fn) do
    timer_pid = self()

    fn ->
      if stop_fn.() do
        :ok = stop(timer_pid)
      else
        send_reminder_fn.()
      end
    end
  end

  @spec reinitialize_after_snooze(State.t()) ::
          {:ok, State.t()} | {:error, {:unsnooze_failed, any()}}
  defp reinitialize_after_snooze(state) do
    case RunInterval.apply_interval(state.interval, state.remind_func) do
      {:ok, timer} ->
        updated_state = Map.put(state, :timer, {:interval_timer, timer})
        {:ok, updated_state}

      {:error, reason} ->
        {:error, {:unsnooze_failed, reason}}
    end
  end

  @spec cancel_before_snooze(:timer.tref()) :: :ok | {:error, any}
  defp cancel_before_snooze(timer_ref) do
    case RunInterval.cancel(timer_ref) do
      :ok -> :ok
      {:error, reason} -> {:error, {:interval_cancel_failed, reason}}
    end
  end

  @spec schedule_unsnooze(GenServer.name(), non_neg_integer()) ::
          {:ok, :timer.tref()} | {:error, {:unsnooze_schedule_failed, any}}
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

  @spec unsnooze(GenServer.name()) :: term
  defp unsnooze(destination) do
    GenServer.call(destination, :unsnooze)
  end

  @spec send_initial_unsnooze_message(pid(), (-> any())) ::
          {:ok, State.t()} | {:error, {:unsnooze_init_message_failed, any()}}
  defp send_initial_unsnooze_message(supervisor, remind_func) do
    case Task.Supervisor.start_child(supervisor, remind_func) do
      {:ok, _} ->
        :ok

      {:ok, _, _} ->
        :ok

      :ignore ->
        Logger.warning("Did not send initial reminder after unsnooze; task was ignored")
        {:error, {:unsnooze_init_message_failed, :ignore}}

      {:error, reason} ->
        Logger.error(
          "Failed to start task to send initial reminder after unsnooze #{inspect(reason)}"
        )

        {:error, {:unsnooze_init_message_failed, reason}}
    end
  end
end
