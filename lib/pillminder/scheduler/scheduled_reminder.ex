defmodule Pillminder.Scheduler.ScheduledReminder do
  @moduledoc """
  A ScheduledReminder is a reminder that the scheduler can use to begin kicking off the sending of reminders.
  """

  @enforce_keys [:start_time, :scheduled_func]
  defstruct [:start_time, :scheduled_func]

  @type t() :: %__MODULE__{
          start_time: Time.t(),
          scheduled_func: (() -> any())
        }
end
