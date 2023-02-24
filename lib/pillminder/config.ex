defmodule Pillminder.Config do
  import Norm

  @doc """
  Load the available timers from the application environment. Throws an exception
  if the data does not conform to the typespec set forth in Pillminder.Config.Timer
  """
  @spec load_timers_from_env!() :: [Pillminder.Config.Timer]
  def load_timers_from_env!() do
    timers = Application.get_env(:pillminder, :timers)

    Enum.map(timers, &load_timer!/1)
  end

  @spec load_timer!(keyword()) :: Pillminder.Config.Timer
  defp load_timer!(config_timer) do
    conform!(
      %Pillminder.Config.Timer{
        id: config_timer[:id],
        reminder_spacing: config_timer[:reminder_spacing] * 1000,
        reminder_start_time: config_timer[:reminder_start_time],
        reminder_start_time_fudge: Keyword.get(config_timer, :reminder_start_time_fudge, 0),
        ntfy_topic: config_timer[:ntfy_topic]
      },
      Pillminder.Config.Timer.s()
    )
  end
end
