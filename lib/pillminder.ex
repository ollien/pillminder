defmodule Pillminder do
  alias Pillminder.ReminderServer
  alias Pillminder.Config

  @spec send_reminders([Config.Timer]) :: :ok | {:error, any}
  def send_reminders([]) do
    :ok
  end

  def send_reminders([next_timer | rest]) do
    with :ok <- send_reminder_for_timer(next_timer) do
      send_reminders(rest)
    else
      err -> err
    end
  end

  @spec send_reminder_for_timer(Config.Timer) :: :ok | {:error, any}
  defp send_reminder_for_timer(timer) do
    ReminderServer.send_reminder_on_interval(timer.reminder_spacing,
      # TODO: We should find a way to nomalize this a bit, rather than repeating what we did in the application config
      server_name: Pillminder.Application.reminder_server_via_tuple(timer)
    )
  end
end
