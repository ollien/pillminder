defmodule Pillminder.ReminderServer.TimerAgent do
  @moduledoc """
  An agent that holds the state of a timer from `RunInterval.apply_interval/2`. `:timer.apply_interval/4` links
  the interval to the process which spawns it, so we use an agent to act as that process.
  """

  use Agent

  alias Pillminder.Util.RunInterval

  @doc """
  Start a timer agent, which will call `RunInterval.apply_interval/2` with the given arguments. If {:ok, pid()} is
  returned, the pid is guaranteed to be an agent with an already-running timer ref
  """
  @spec start_link({number(), (() -> any())}) :: {:ok, pid()} | {:error, any()}
  def start_link({interval, send_reminder_fn}) do
    with {:ok, agent_pid} <-
           Agent.start_link(fn -> make_initial_timer_state(interval, send_reminder_fn) end),
         # From the Agent docs, start_link will not return until the init function has returned, so we are guaranteed
         # to have the result of apply_interval, whether failed or not.
         :ok <- ensure_timer_started(agent_pid) do
      {:ok, agent_pid}
    end
  end

  @spec make_initial_timer_state(number(), (() -> any())) :: :timer.tref() | {:error, any()}
  defp make_initial_timer_state(interval, send_reminder_fn) do
    RunInterval.apply_interval(interval, send_reminder_fn) |> unwrap_ok
  end

  @spec ensure_timer_started(pid()) :: :ok | {:error, {:timer_start_failed, any()}}
  defp ensure_timer_started(agent_pid) do
    case Agent.get(agent_pid, & &1) do
      {:error, reason} ->
        # Kill the agent so that it isn't hanging around with an error state
        Agent.stop(agent_pid)
        {:error, {:timer_start_failed, reason}}

      _timer_ref ->
        :ok
    end
  end

  @spec unwrap_ok({:ok, value} | value) :: value when value: any()
  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok(value), do: value
end
