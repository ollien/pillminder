defmodule Pillminder.ReminderSender.TimerManager do
  @moduledoc """
  A supervisor used to keep track of interval timers.
  """
  require Logger

  use Supervisor

  alias Pillminder.ReminderSender.SendServer
  alias Pillminder.ReminderSender.ReminderTimer

  @timer_supervisor_name __MODULE__.TimerSupervisor
  @registry_name __MODULE__.Registry

  @type stop_func :: (() -> boolean())

  @spec start_link(any) :: Supervisor.on_start()
  def start_link(_init) do
    Supervisor.start_link(__MODULE__, :no_arg, name: __MODULE__)
  end

  @impl true
  def init(_init) do
    children = [
      {Registry, keys: :unique, name: @registry_name},
      {DynamicSupervisor, strategy: :one_for_one, name: @timer_supervisor_name}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Start a reminder timer that will call send_reminder_fn every interval. The task will be supervised, but will
  not be restarted after a timer cancel.

  If a stop_func is provided, it will stop reminding once that function returns true.]
  """
  @spec start_reminder_timer(any(), number, SendServer.remind_func(), stop_func()) ::
          :ok | {:error, any}
  def start_reminder_timer(id, interval, send_reminder_fn, stop_func \\ &never_stop/0) do
    reminder_timer_child_spec =
      Supervisor.child_spec(
        {ReminderTimer, {id, interval, send_reminder_fn, stop_func, [name: make_via_tuple(id)]}},
        restart: :transient
      )

    case DynamicSupervisor.start_child(@timer_supervisor_name, reminder_timer_child_spec) do
      {:ok, _pid} -> :ok
      :ignore -> {:error, :ignore}
      {:error, {:already_started, _}} -> {:error, :already_timing}
      err = {:error, _reason} -> err
    end
  end

  @doc """
  Cancel the timer with the given id. Returns :not_timing if the given timer does not exist.
  """
  @spec cancel_timer(any) :: :ok | {:error, :not_timing}
  def cancel_timer(id) do
    try do
      ReminderTimer.stop(make_via_tuple(id))
    catch
      :exit, {:noproc, _} -> {:error, :not_timing}
    end
  end

  @doc """
  Cancel the timer with the given id. Returns :not_timing if the given timer does not exist.
  """
  @spec snooze_timer(any, non_neg_integer()) :: :ok | {:error, :not_timing}
  def snooze_timer(id, snooze_ms) do
    try do
      ReminderTimer.snooze(make_via_tuple(id), snooze_ms)
    catch
      :exit, {:noproc, _} -> {:error, :not_timing}
    end
  end

  defp make_via_tuple(id) do
    {:via, Registry, {@registry_name, id}}
  end

  defp never_stop() do
    false
  end
end
