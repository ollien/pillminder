defmodule Pillminder do
  alias Pillminder.ReminderSender
  alias Pillminder.Config

  @spec send_reminder_for_timer(Config.Timer.t()) :: :ok | {:error, any}
  def send_reminder_for_timer(timer) do
    ReminderSender.send_reminder_on_interval(
      timer.id,
      timer.reminder_spacing,
      send_immediately: true
    )
  end

  @doc """
  Look up the given timer in the configuration, returns nil if not found.

  Note: this technically throws on an invalid config, but after initial application startup, this is unlikely
  to happen.
  """
  @spec lookup_timer(String.t()) :: Config.Timer.t() | nil
  def lookup_timer(timer_id) do
    Config.load_timers_from_env!()
    |> Enum.find(fn timer -> timer.id == timer_id end)
  end

  def get_base_url() do
    Application.get_env(:pillminder, :base_url)
  end
end
