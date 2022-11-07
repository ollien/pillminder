defmodule Pillminder do
  alias Pillminder.ReminderServer

  @spec send_reminders(non_neg_integer) :: :ok | {:error, any}
  def send_reminders(interval) do
    case ReminderServer.send_reminder_on_interval(interval) do
      {:ok, uuid} ->
        # HACK: I didn't leave myself a way to get the uuid into the notification so as a temporary measure I'm printing
        # it out
        IO.inspect(uuid)
        :ok

      {:error, err} ->
        {:error, err}
    end
  end
end
