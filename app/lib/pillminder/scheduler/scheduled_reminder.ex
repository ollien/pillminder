defmodule Pillminder.Scheduler.ScheduledReminder do
  @moduledoc """
  A ScheduledReminder is a reminder that the scheduler can use to begin kicking off the sending of reminders.
  """

  @enforce_keys [:id, :start_time, :time_zone, :scheduled_func]
  defstruct [:id, :start_time, :time_zone, :scheduled_func]

  @type t() :: %__MODULE__{
          id: String.t(),
          start_time: Pillminder.Scheduler.StartTime.start_time_func(),
          time_zone: Timex.Types.time_zone(),
          scheduled_func: (() -> any())
        }
end
