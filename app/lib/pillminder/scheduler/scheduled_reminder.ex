defmodule Pillminder.Scheduler.ScheduledReminder do
  @moduledoc """
  A ScheduledReminder is a reminder that the scheduler can use to begin kicking off the sending of reminders.
  """

  @enforce_keys [:id, :start_time, :scheduled_func]
  defstruct [:id, :start_time, :scheduled_func, start_time_fudge: 0]

  @type t() :: %__MODULE__{
          id: String.t(),
          start_time: Pillminder.Scheduler.StartTime.start_time_func(),
          scheduled_func: (() -> any())
        }
end
