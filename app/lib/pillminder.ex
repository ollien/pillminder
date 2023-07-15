defmodule Pillminder do
  alias Pillminder.ReminderSender
  alias Pillminder.Config
  alias Pillminder.Util

  @spec send_reminder_for_timer(Config.Timer.t()) :: :ok | {:error, any}
  def send_reminder_for_timer(timer) do
    now = Util.Time.now!(timer.reminder_time_zone)

    case Timex.end_of_day(now) do
      {:error, reason} ->
        {:error, {:stop_time_calculation, reason}}

      stop_time ->
        ReminderSender.send_reminder_on_interval(
          timer.id,
          timer.reminder_spacing,
          send_immediately: true,
          stop_time: stop_time
        )
    end
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

  @spec lookup_timer!(String.t()) :: Config.Timer.t()
  def lookup_timer!(timer_id) do
    case lookup_timer(timer_id) do
      nil ->
        # Should never happen when run properly, but we can't make that assumption
        raise "Cannot find timer #{timer_id}"

      timer ->
        timer
    end
  end

  def get_base_url() do
    Application.get_env(:pillminder, :base_url)
  end
end
