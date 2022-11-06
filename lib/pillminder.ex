defmodule Pillminder do
  alias Pillminder.RunInterval

  @spec send_reminders(non_neg_integer) :: :ok | {:error, any}
  def send_reminders(interval) do
    timer_start_res =
      RunInterval.apply_interval(interval, fn ->
        # We want to time out the call once our next interval hits
        Pillminder.ReminderServer.send_reminder(interval)
      end)

    case timer_start_res do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end
end
