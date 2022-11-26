defmodule Pillminder.ReminderSender.TimerSupervisor do
  @moduledoc """
  A supervisor used to keep track of interval timers.
  """
  require Logger

  use DynamicSupervisor

  alias Pillminder.ReminderSender.TimerAgent

  @spec start_link(any) :: Supervisor.on_start()
  def start_link(_init) do
    DynamicSupervisor.start_link(__MODULE__, :no_arg, name: __MODULE__)
  end

  @impl true
  def init(_init) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start a timer agent that will call send_reminder_fn every interval. The task will be supervised, but will
  have a temporary restart strategy, so you may maintain a reference to its pid, and/or stop it if you wish.
  """
  @spec start_timer_agent(number, Pillminder.ReminderSender.remind_func()) ::
          {:ok, pid} | {:error, any}
  def start_timer_agent(interval, send_reminder_fn) do
    timer_agent_child_spec =
      Supervisor.child_spec(
        {TimerAgent, {interval, send_reminder_fn}},
        restart: :temporary
      )

    case DynamicSupervisor.start_child(__MODULE__, timer_agent_child_spec) do
      {:ok, pid} -> {:ok, pid}
      :ignore -> {:error, :ignore}
      err = {:error, _reason} -> err
    end
  end
end
