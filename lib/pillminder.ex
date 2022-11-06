defmodule Pillminder do
  alias Pillminder.RunInterval

  @spec send_reminders(non_neg_integer) :: :ok | {:error, any}
  def send_reminders(interval) do
    timer_start_res =
      RunInterval.apply_interval(interval, &Pillminder.ReminderServer.send_reminder/0)

    case timer_start_res do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end
end
