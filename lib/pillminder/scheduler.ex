defmodule Pillminder.Scheduler do
  alias Pillminder.Util
  use Task

  @type clock_source :: (() -> DateTime.t())
  @type init_options :: [clock_source: clock_source()]
  @type state :: %{clock_source: clock_source()}
  @type scheduled_reminder :: %{
          start_time: Time.t(),
          scheduled_func: (() -> any())
        }

  @spec start_link({[scheduled_reminder()], init_options()}) :: {:ok, pid}
  def start_link({reminders, opts}) do
    Task.start(__MODULE__, :schedule_reminders, [reminders, opts])
  end

  @spec schedule_reminders([scheduled_reminder()], init_options()) :: :ok
  def schedule_reminders(reminders, opts \\ []) do
    clock_source = Keyword.get(opts, :clock_source, &now!/0)
    now = clock_source.()
    {:ok, to_schedule} = get_next_scheduleable_times(reminders, now)

    Enum.each(to_schedule, fn {reminder, schedule_time} ->
      {:ok, ms_until} = get_ms_until(now, schedule_time)
      schedule_reminder(reminder, ms_until, clock_source)
    end)
  end

  @spec now!() :: DateTime.t()
  defp now!() do
    with {:ok, now} <- Timex.local() |> ok_or() do
      now
    else
      err -> raise "Could not get current time #{err}"
    end
  end

  @spec ok_or(value | {:error, err}) :: {:ok, value} | {:error, err} when value: any, err: any
  defp ok_or(err = {:error, _}) do
    err
  end

  defp ok_or(value) do
    {:ok, value}
  end

  @spec get_next_scheduleable_times(reminders :: [scheduled_reminder()], now :: DateTime.t()) ::
          {:ok, [{scheduled_reminder(), DateTime.t()}]} | {:error, String.t()}
  defp get_next_scheduleable_times(reminders, now) do
    Enum.reverse(reminders)
    |> Enum.reduce_while([], fn reminder, acc ->
      case get_next_scheduleable_time(reminder, now) do
        {:ok, reminder_time} ->
          {:cont, [{reminder, reminder_time} | acc]}

        {:error, err} ->
          err_msg =
            "Failed to determine next time for reminder with start time #{Time.to_iso8601(reminder.start_time)}: #{err}"

          {:halt, {:error, err_msg}}
      end
    end)
    |> ok_or()
  end

  @spec get_next_scheduleable_time(reminder :: scheduled_reminder(), now :: DateTime.t()) ::
          {:ok, DateTime.t()} | {:error, String.t()}
  defp get_next_scheduleable_time(reminder, now) do
    Util.Time.get_next_occurrence_of_time(now, reminder.start_time) |> ok_or()
  end

  @spec get_ms_until(DateTime.t(), DateTime.t()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  defp get_ms_until(now, time) do
    with {:ok, ms_until} <- Timex.diff(time, now, :milliseconds) |> ok_or() do
      {:ok, ms_until}
    else
      {:error, err} ->
        err_msg =
          "Failed to get ms from #{Time.to_iso8601(now)} to #{Time.to_iso8601(time)}: #{err}"

        {:error, err_msg}
    end
  end

  @spec schedule_reminder(scheduled_reminder(), non_neg_integer(), clock_source()) :: :ok
  defp schedule_reminder(reminder, ms_until, clock_source) do
    {:ok, _} =
      :timer.apply_after(
        ms_until,
        :erlang,
        :apply,
        # We must use :erlang.apply if we want to use a private function here
        [fn -> run_and_reschedule(reminder, clock_source) end, []]
      )

    :ok
  end

  defp run_and_reschedule(reminder, clock_source) do
    # TODO: Run this as a spawn_monitor
    reminder.scheduled_func.()

    now = clock_source.()
    {:ok, schedule_time} = get_next_scheduleable_time(reminder, now)
    {:ok, ms_until} = get_ms_until(now, schedule_time)
    schedule_reminder(reminder, ms_until, clock_source)
  end
end
