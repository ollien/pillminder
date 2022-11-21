defmodule Pillminder.Scheduler do
  require Logger

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
    {:ok, supervisor} = Task.Supervisor.start_link()
    Task.start(__MODULE__, :schedule_reminders, [reminders, supervisor, opts])
  end

  @spec schedule_reminders([scheduled_reminder()], pid, init_options()) :: :ok
  def schedule_reminders(reminders, supervisor, opts \\ []) do
    clock_source = Keyword.get(opts, :clock_source, &now!/0)
    now = clock_source.()
    {:ok, to_schedule} = get_next_scheduleable_times(reminders, now)

    Enum.each(to_schedule, fn {reminder, schedule_time} ->
      {:ok, ms_until} = get_ms_until(now, schedule_time)
      schedule_reminder(supervisor, reminder, ms_until, clock_source)
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

  @spec schedule_reminder(
          pid,
          scheduled_reminder(),
          non_neg_integer(),
          clock_source()
        ) :: :ok
  defp schedule_reminder(supervisor, reminder, ms_until, clock_source) do
    minutes_until =
      Timex.Duration.from_milliseconds(ms_until)
      |> Timex.Duration.to_minutes()
      |> (&:io_lib.format("~.2f", [&1])).()

    Logger.debug("Scheduling reminder for #{reminder.start_time} (in #{minutes_until} minutes))")

    {:ok, _} =
      :timer.apply_after(
        ms_until,
        :erlang,
        :apply,
        # We must use :erlang.apply if we want to use a private function here
        [fn -> run_and_reschedule(supervisor, reminder, clock_source) end, []]
      )

    :ok
  end

  @spec run_and_reschedule(pid, scheduled_reminder(), clock_source()) :: :ok
  defp run_and_reschedule(supervisor, reminder, clock_source) do
    supervised_task = Task.Supervisor.async_nolink(supervisor, reminder.scheduled_func)
    # TODO: Should we pick a timeout here?
    case Task.yield(supervised_task, :infinity) do
      {:ok, _} -> Logger.debug("Reminder task completed")
      {:exit, :normal} -> Logger.debug("Reminder task completed")
      {:exit, reason} -> Logger.error("Reminder task failed: #{inspect(reason)}")
    end

    # The only other possible return values for this are :ignore and :already_started, neither of which
    # can happen here.
    {:ok, _} =
      Task.Supervisor.start_child(
        supervisor,
        fn ->
          reschedule_reminder(supervisor, reminder, clock_source)
        end,
        restart: :transient
      )

    :ok
  end

  @spec reschedule_reminder(pid, scheduled_reminder(), clock_source()) :: :ok
  defp reschedule_reminder(supervisor, reminder, clock_source) do
    now = clock_source.()
    {:ok, schedule_time} = get_next_scheduleable_time(reminder, now)
    {:ok, ms_until} = get_ms_until(now, schedule_time)
    schedule_reminder(supervisor, reminder, ms_until, clock_source)
  end
end
