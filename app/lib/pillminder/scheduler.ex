defmodule Pillminder.Scheduler do
  @moduledoc """
  The Scheduler kicks off setting up daily reminders to take medication. Every day,
  a single call is made to the given `scheduled_func` in a `ScheduledReminder`
  """

  require Logger

  alias Pillminder.Scheduler.ScheduledReminder
  alias Pillminder.Util
  use Supervisor

  @type clock_source :: (() -> DateTime.t())
  @type init_options :: [clock_source: clock_source()]

  @task_supervisor_name __MODULE__.TaskSupervisor

  @spec start_link({[ScheduledReminder.t()], init_options()}) ::
          {:ok, pid} | {:error, any} | :ignore
  def start_link({reminders, opts}) do
    Supervisor.start_link(__MODULE__, {reminders, opts}, name: __MODULE__)
  end

  @impl true
  def init({reminders, opts}) do
    children = [
      {Task.Supervisor, name: @task_supervisor_name},
      {Task, fn -> schedule_reminders(reminders, opts) end}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
    Schedule reminders to be run at the time indicated by their start time. These reminders will run to completion,
    and then be rescheduled for the given time.
  """
  @spec schedule_reminders([ScheduledReminder.t()], init_options()) :: :ok
  def schedule_reminders(reminders, opts \\ []) do
    clock_source = Keyword.get(opts, :clock_source, &Util.Time.now!/0)
    now = clock_source.()
    {:ok, to_schedule} = get_next_scheduleable_times(reminders, now)

    Enum.each(to_schedule, fn {reminder, schedule_time} ->
      {:ok, ms_until} = get_ms_until(now, schedule_time)
      schedule_reminder(reminder, ms_until, clock_source)
    end)
  end

  @spec get_next_scheduleable_times(reminders :: [ScheduledReminder.t()], now :: DateTime.t()) ::
          {:ok, [{ScheduledReminder.t(), DateTime.t()}]} | {:error, String.t()}
  defp get_next_scheduleable_times(reminders, now) do
    Enum.reverse(reminders)
    |> Enum.reduce_while([], fn reminder, acc ->
      case get_next_scheduleable_time(reminder, now) do
        {:ok, reminder_time} ->
          {:cont, [{reminder, reminder_time} | acc]}

        {:error, err} ->
          err_msg = ~s(Failed to determine next time for reminder "#{reminder.id}": #{err})

          {:halt, {:error, err_msg}}
      end
    end)
    |> Util.Error.ok_or()
  end

  @spec get_next_scheduleable_time(reminder :: ScheduledReminder.t(), now :: DateTime.t()) ::
          {:ok, DateTime.t()} | {:error, String.t()}
  defp get_next_scheduleable_time(reminder, now) do
    reminder.start_time.(now)
  end

  @spec get_ms_until(DateTime.t(), DateTime.t()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  defp get_ms_until(now, time) do
    case Timex.diff(time, now, :milliseconds) |> Util.Error.ok_or() do
      {:ok, ms_until} ->
        {:ok, ms_until}
        {:ok, ms_until}

      {:error, err} ->
        err_msg =
          "Failed to get ms from #{Time.to_iso8601(now)} to #{Time.to_iso8601(time)}: #{err}"

        {:error, err_msg}
    end
  end

  @spec schedule_reminder(
          ScheduledReminder.t(),
          non_neg_integer(),
          clock_source()
        ) :: :ok
  defp schedule_reminder(reminder, ms_until, clock_source) do
    log_reminder_schedule(reminder, ms_until, clock_source)

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

  defp log_reminder_schedule(reminder, ms_until, clock_source) do
    get_start_time = fn ->
      duration_until = Timex.Duration.from_milliseconds(ms_until)
      now = clock_source.()

      # this is technically approximate but it's just for a log so it's not a big deal if it's slightly off
      Timex.add(now, duration_until)
    end

    minutes_until = fn ->
      Timex.Duration.from_milliseconds(ms_until)
      |> Timex.Duration.to_minutes()
      |> (&:io_lib.format("~.2f", [&1])).()
    end

    Logger.info(
      "Scheduling reminder \"#{reminder.id}\" for #{get_start_time.() |> DateTime.truncate(:second)} (in #{minutes_until.()} minutes)"
    )
  end

  @spec run_and_reschedule(ScheduledReminder.t(), clock_source()) :: nil
  defp run_and_reschedule(reminder, clock_source) do
    run_reminder_task(reminder)
    run_reschedule_task(reminder, clock_source)
  end

  @spec run_reminder_task(ScheduledReminder.t()) :: nil
  defp run_reminder_task(reminder) do
    func_task = Task.Supervisor.async_nolink(@task_supervisor_name, reminder.scheduled_func)
    # TODO: Should we pick a timeout here?
    case Task.yield(func_task, :infinity) do
      {:ok, _} ->
        Logger.debug("Reminder task for \"#{reminder.id}\" completed")

      {:exit, :normal} ->
        Logger.debug("Reminder task for \"#{reminder.id}\"completed")

      {:exit, reason} ->
        Logger.error("Reminder task for \"#{reminder.id}\" failed: #{inspect(reason)}")
    end

    nil
  end

  @spec run_reschedule_task(ScheduledReminder.t(), clock_source()) :: nil
  defp run_reschedule_task(reminder, clock_source) do
    # GenRetry.Task.Supervisor.async_nolink doesn't accept a name, so we must emulate it
    reschedule_task =
      Task.Supervisor.async_nolink(
        @task_supervisor_name,
        GenRetry.Task.task_function(
          fn -> reschedule_reminder(reminder, clock_source) end,
          # We _REALLY_ want this to be scheduled; failure isn't quite an option.
          retries: :infinity,
          # ... but we probably don't want exponential backoff in that case.
          exp_base: 1
        )
      )

    # The only other possible return values for this are :ignore and :already_started, neither of which
    # can happen here.
    case Task.yield(reschedule_task, :infinity) do
      {:ok, _} -> :ok
      {:exit, :normal} -> :ok
      # I don't believe this can really happen, given we have infinite retries.
      {:exit, reason} -> Logger.error("Rescheduling reminder task failed: #{inspect(reason)}")
    end

    nil
  end

  @spec reschedule_reminder(ScheduledReminder.t(), clock_source()) :: :ok
  defp reschedule_reminder(reminder, clock_source) do
    now = clock_source.()
    {:ok, schedule_time} = get_next_scheduleable_time(reminder, now)
    {:ok, ms_until} = get_ms_until(now, schedule_time)
    schedule_reminder(reminder, ms_until, clock_source)
  end
end
