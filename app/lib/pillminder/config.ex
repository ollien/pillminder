defmodule Pillminder.Config do
  import Norm

  @doc """
  Load the HTTP server configuration from the application environment. Throws
  an exception if the data does not set form to the typespec set forth in
  Pillminder.Config.Server.
  """
  @spec load_server_settings_from_env!() :: Pillminder.Config.Server.t()
  def load_server_settings_from_env!() do
    server_config =
      case Application.fetch_env(:pillminder, :server) do
        {:ok, value} -> value
        :error -> []
      end

    conform!(
      struct(Pillminder.Config.Server, server_config),
      Pillminder.Config.Server.s()
    )
  end

  @doc """
  Load the available timers from the application environment. Throws an exception
  if the data does not conform to the typespec set forth in Pillminder.Config.Timer
  """
  @spec load_timers_from_env!() :: [Pillminder.Config.Timer.t()]
  def load_timers_from_env!() do
    timers = Application.fetch_env!(:pillminder, :timers)

    Enum.map(timers, &load_timer!/1)
  end

  @spec load_timer!(keyword()) :: Pillminder.Config.Timer.t()
  defp load_timer!(config_timer) do
    conform!(
      %Pillminder.Config.Timer{
        id: config_timer[:id],
        reminder_spacing: config_timer[:reminder_spacing] * 1000,
        reminder_start_time: config_timer[:reminder_start_time],
        reminder_time_zone: config_timer[:reminder_time_zone],
        reminder_start_time_fudge: Keyword.get(config_timer, :reminder_start_time_fudge, 0),
        ntfy_topic: config_timer[:ntfy_topic],
        ntfy_api_key: config_timer[:ntfy_api_key]
      },
      Pillminder.Config.Timer.s()
    )
  end
end
