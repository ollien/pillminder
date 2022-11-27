defmodule Pillminder.ReminderSender.TimerManager do
  @moduledoc """
  A supervisor used to keep track of interval timers.
  """
  require Logger

  use Supervisor

  alias Pillminder.ReminderSender.SendServer
  alias Pillminder.ReminderSender.TimerAgent

  @timer_supervisor_name __MODULE__.TimerSupervisor
  @registry_name __MODULE__.Registry

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
  Start a timer agent that will call send_reminder_fn every interval. The task will be supervised, but will
  have a temporary restart strategy, so you may maintain a reference to its pid, and/or stop it if you wish.
  """
  @spec start_timer_agent(any(), number, SendServer.remind_func()) ::
          {:ok, pid} | {:error, any}
  def start_timer_agent(id, interval, send_reminder_fn) do
    timer_agent_child_spec =
      Supervisor.child_spec(
        {TimerAgent, {interval, send_reminder_fn, [name: make_via_tuple(id)]}},
        restart: :temporary
      )

    case DynamicSupervisor.start_child(@timer_supervisor_name, timer_agent_child_spec) do
      {:ok, pid} -> {:ok, pid}
      :ignore -> {:error, :ignore}
      {:error, {:already_started, _}} -> {:error, :already_timing}
      err = {:error, _reason} -> err
    end
  end

  @doc """
  Cancel the timer with the given id. Returns :no_timer if the given timer does not exist.
  """
  @spec cancel_timer(any) :: :ok | {:error, :no_timer}
  def cancel_timer(id) do
    try do
      TimerAgent.stop(make_via_tuple(id))
    catch
      :exit, {:noproc, _} -> {:error, :no_timer}
    end
  end

  @doc """
  Cancel the timer with the given id. Returns :no_timer if the given timer does not exist.
  """
  @spec snooze_timer(any, non_neg_integer()) :: :ok | {:error, :no_timer}
  def snooze_timer(id, snooze_ms) do
    try do
      TimerAgent.snooze(make_via_tuple(id), snooze_ms)
    catch
      :exit, {:noproc, _} -> {:error, :no_timer}
    end
  end

  defp make_via_tuple(id) do
    {:via, Registry, {@registry_name, id}}
  end
end
