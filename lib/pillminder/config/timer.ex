defmodule Pillminder.Config.Timer do
  @moduledoc """
  A single Timer that will reminder a user to take their medication
  """

  import Norm
  @enforce_keys [:id, :reminder_spacing, :reminder_start_time, :ntfy_topic]
  defstruct [
    :id,
    :reminder_spacing,
    :reminder_start_time,
    :ntfy_topic,
    reminder_start_time_fudge: 0
  ]

  @type t() :: %__MODULE__{
          id: String.t(),
          reminder_spacing: non_neg_integer(),
          reminder_start_time: Time.t(),
          ntfy_topic: String.t(),
          reminder_start_time_fudge: non_neg_integer()
        }

  def s,
    do:
      schema(%Pillminder.Config.Timer{
        id: spec(is_binary()),
        reminder_spacing: spec(is_integer() and (&(&1 > 0))),
        reminder_start_time: schema(%{__struct__: Time}),
        reminder_start_time_fudge: spec(is_integer() and (&(&1 >= 0))),
        ntfy_topic: spec(is_binary())
      })
end
