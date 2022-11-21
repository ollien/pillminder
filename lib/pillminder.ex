defmodule Pillminder do
  alias Pillminder.ReminderServer
  alias Pillminder.Config

  @spec send_reminder_for_timer(Config.Timer) :: :ok | {:error, any}
  def send_reminder_for_timer(timer) do
    ReminderServer.send_reminder_on_interval(timer.reminder_spacing,
      server_name: Pillminder.Application.reminder_server_via_tuple(timer)
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
        }
      ]
    }
  end

  defp get_base_url() do
    Application.get_env(:pillminder, :base_url)
  end
end
