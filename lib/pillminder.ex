defmodule Pillminder do
  alias Pillminder.ReminderServer
  alias Pillminder.Config

  @spec send_reminder_for_timer(Config.Timer) :: :ok | {:error, any}
  def send_reminder_for_timer(timer) do
    ReminderServer.send_reminder_on_interval(timer.reminder_spacing,
      # TODO: We should find a way to nomalize this a bit, rather than repeating what we did in the application config
      server_name: Pillminder.Application.reminder_server_via_tuple(timer)
    )
  end
end
