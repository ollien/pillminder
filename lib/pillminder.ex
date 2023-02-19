defmodule Pillminder do
  alias Pillminder.ReminderSender
  alias Pillminder.Config

  @spec send_reminder_for_timer(Config.Timer) :: :ok | {:error, any}
  def send_reminder_for_timer(timer) do
    ReminderSender.send_reminder_on_interval(
      timer.id,
      timer.reminder_spacing,
      send_immediately: true
    )
  end

  def get_base_url() do
    Application.get_env(:pillminder, :base_url)
  end
end
