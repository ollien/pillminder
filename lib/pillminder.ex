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

  def make_notification_body(timer) do
    %{
      title: "Time to take your medication!",
      actions: [
        %{
          action: "http",
          label: "Mark taken",
          clear: true,
          url: URI.merge(get_base_url(), "/timer/#{URI.encode(timer.id)}"),
          method: "DELETE"
        },
        %{
          action: "http",
          label: "Snooze 1hr",
          clear: true,
          url: URI.merge(get_base_url(), "/timer/#{URI.encode(timer.id)}/snooze"),
          method: "POST"
        }
      ]
    }
  end

  defp get_base_url() do
    Application.get_env(:pillminder, :base_url)
  end
end
