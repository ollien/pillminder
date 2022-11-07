defmodule Pillminder do
  alias Pillminder.ReminderServer

  @spec send_reminders(non_neg_integer) :: :ok | {:error, any}
  def send_reminders(interval) do
    case ReminderServer.send_reminder_on_interval(interval) do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end
end
