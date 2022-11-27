defmodule Pillminder.ReminderSender.TimerAgent do
  @moduledoc """
  An agent that holds the state of a timer from `RunInterval.apply_interval/2`. `:timer.apply_interval/4` links
  the interval to the process which spawns it, so we use an agent to act as that process.
  """

  use Agent

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
    with {:ok, agent_pid} <-
           Agent.start_link(fn -> make_initial_timer_state(interval, send_reminder_fn) end, opts),
         # From the Agent docs, start_link will not return until the init function has returned, so we are guaranteed
         # to have the result of apply_interval, whether failed or not.
         :ok <- ensure_timer_started(agent_pid) do
      {:ok, agent_pid}
    end
  end

  @doc """
  Stop the timer agent. See `Agent.stop/3` for more details.
  """
  @spec stop(Agent.agent(), atom, non_neg_integer | :infinity) :: any
  def stop(agent, reason \\ :normal, timeout \\ 5000) do
    Agent.stop(agent, reason, timeout)
  end

  @doc """
  Snooze the current timer
  """
  @spec snooze(
          Agent.agent(),
          non_neg_integer,
          non_neg_integer | :infinity
        ) :: :ok
  def snooze(agent, snooze_ms, timeout \\ 5000) do
    Agent.update(
      agent,
      fn state = %State{
           timer: {:interval_timer, timer_ref},
           interval: interval
         } ->
        with :ok <- cancel_before_snooze(timer_ref),
             {:ok, timer_ref} <- schedule_unsnooze(agent, snooze_ms, interval, timeout) do
          Map.put(state, :timer, {:snoozed_timer, timer_ref})
        else
          # We really can't recover from something like this. We could attempt to reschedule the original interval
          # timer but that would be difficult to deal with (what if that reschedule failed?)
          {:error, reason} -> raise({:snooze_failed, reason})
        end
      end,
      timeout
    )
  end

  @spec make_initial_timer_state(number(), (() -> any())) :: State.t() | {:error, any()}
  defp make_initial_timer_state(interval, send_reminder_fn) do
    case RunInterval.apply_interval(interval, send_reminder_fn) do
      {:ok, timer_ref} ->
        %State{
          timer: {:interval_timer, timer_ref},
          interval: interval,
          remind_func: send_reminder_fn
        }

      err = {:error, _err} ->
        err
    end
  end

  @spec ensure_timer_started(pid()) :: :ok | {:error, {:timer_start_failed, any()}}
  defp ensure_timer_started(agent_pid) do
    case Agent.get(agent_pid, & &1) do
      {:error, reason} ->
        # Kill the agent so that it isn't hanging around with an error state
        Agent.stop(agent_pid)
        {:error, {:timer_start_failed, reason}}

      %State{timer: {:interval_timer, _timer_ref}} ->
        :ok

      %State{timer: {:snoozed_timer, _timer_ref}} ->
        :ok
    end
  end

  @spec cancel_before_snooze(:timer.tref()) :: :ok | {:error, any}
  defp cancel_before_snooze(timer_ref) do
    case RunInterval.cancel(timer_ref) do
      :ok -> :ok
      {:error, reason} -> {:error, {:interval_cancel_failed, reason}}
    end
  end

  @spec schedule_unsnooze(
          Agent.agent(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer() | :infinity
        ) :: {:ok, :timer.tref()} | {:error, any}
  defp schedule_unsnooze(agent, snooze_ms, original_interval, timeout) do
    schedule_res =
      RunInterval.apply_after(snooze_ms, fn ->
        reinitialize_after_snooze(agent, original_interval, timeout)
      end)

    case schedule_res do
      {:ok, timer_ref} -> {:ok, timer_ref}
      {:error, reason} -> {:error, {:unsnooze_schedule_failed, reason}}
    end
  end

  @spec reinitialize_after_snooze(Agent.agent(), non_neg_integer(), non_neg_integer() | :infinity) ::
          :ok
  defp reinitialize_after_snooze(agent, interval, timeout) do
    Agent.update(
      agent,
      fn %State{timer: {:snoozed_timer, _timer_ref}, remind_func: remind_func} ->
        make_initial_timer_state(interval, remind_func)
      end,
      timeout
    )
  end
end
