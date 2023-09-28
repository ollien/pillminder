defmodule PillminderTest.Scheduler do
  alias Pillminder.Scheduler

  # Cannot be async, due to several processes being named as __MODULE__
  # It's a lot of plumbing to make this work asynchronously
  # TODO: add that plumbing
  use ExUnit.Case

  doctest Pillminder.Scheduler

  # Make a clock source that will allow for scheduling, then immediately advance to the schedule time
  # While this does technically "peek into" implementation details a bit (as it assumes we will schedule)
  # exactly once, it is still worlds better than counting out the calls
  defp make_clock_source(base_datetime, first_scheduled_datetime) do
    make_agent_state = fn datetime, scheduled_datetime ->
      %{init: datetime, after_schedule: scheduled_datetime, scheduled: false}
    end

    {:ok, times_agent_pid} =
      Agent.start_link(fn -> make_agent_state.(base_datetime, first_scheduled_datetime) end)

    clock_source = fn ->
      Agent.get_and_update(
        times_agent_pid,
        fn
          state = %{init: datetime, scheduled: false} -> {datetime, %{state | scheduled: true}}
          state = %{after_schedule: after_schedule, scheduled: true} -> {after_schedule, state}
        end
      )
    end

    on_schedule = fn advance_fn ->
      Agent.update(times_agent_pid, fn %{init: last_base, after_schedule: last_after_schedule} ->
        advanced_base = advance_fn.(last_base)
        advanced_after_schedule = advance_fn.(last_after_schedule)

        make_agent_state.(advanced_base, advanced_after_schedule)
      end)
    end

    {clock_source, on_schedule}
  end

  test "runs task at specified time" do
    this_pid = self()

    start_supervised!(
      {Scheduler,
       {
         [
           %{
             id: "my-timer",
             start_time: Scheduler.StartTime.next_possible(~T[09:00:00.250Z]),
             scheduled_func: fn -> send(this_pid, :called) end
           }
         ],
         clock_source: fn -> ~U[2022-05-15 09:00:00.000Z] end
       }}
    )

    assert_receive(:called, 500, "Scheduled func was not called")
  end

  test "reschedules itself to run again" do
    {clock_source, update_clock} =
      make_clock_source(~U[2022-05-15 09:00:00.000Z], ~U[2022-05-15 09:00:00.250Z])

    this_pid = self()

    schedule_func = fn ->
      update_clock.(&Timex.add(&1, Timex.Duration.from_days(1)))
      send(this_pid, :called)
    end

    start_supervised!(
      {Scheduler,
       {
         [
           %{
             id: "my-timer",
             start_time: Scheduler.StartTime.next_possible(~T[09:00:00.250Z]),
             scheduled_func: schedule_func
           }
         ],
         clock_source: clock_source
       }}
    )

    assert_receive(:called, 500, "Scheduled func was not called")
    assert_receive(:called, 1000, "Scheduled func was not called a second time")
  end

  test "a crashing task is still rescheduled" do
    {clock_source, update_clock} =
      make_clock_source(~U[2022-05-15 09:00:00.000Z], ~T[09:00:00.250Z])

    this_pid = self()

    schedule_func = fn ->
      update_clock.(&Timex.add(&1, Timex.Duration.from_days(1)))
      send(this_pid, :called)
      :erlang.error(:deliberate_crash)
    end

    start_supervised!(
      {Scheduler,
       {
         [
           %{
             id: "my-timer",
             start_time: Scheduler.StartTime.next_possible(~T[09:00:00.250Z]),
             scheduled_func: schedule_func
           }
         ],
         clock_source: clock_source
       }}
    )

    assert_receive(:called, 500, "Scheduled func was not called")
    assert_receive(:called, 1000, "Scheduled func was not called a second time")
  end

  test "skipping today after a scheduled time does nothing" do
    {clock_source, update_clock} =
      make_clock_source(~U[2023-05-15 23:59:59.750Z], ~U[2023-05-16 00:00:00.000Z])

    this_pid = self()

    schedule_func = fn ->
      update_clock.(&Timex.add(&1, Timex.Duration.from_days(1)))
      send(this_pid, :called)
    end

    start_supervised!(
      {Scheduler,
       {
         [
           %{
             id: "my-timer",
             start_time: Scheduler.StartTime.next_possible(~T[00:00:00.000Z]),
             scheduled_func: schedule_func
           }
         ],
         clock_source: clock_source
       }}
    )

    # its currently 23:59:59.750, so today's reminder has already gone off (at 00:00:00).
    # We want to make sure the reminder at 00:00:00 (the next day) still goes off
    Scheduler.dont_remind_today("my-timer", ~D[2023-05-15])
    assert_receive(:called, 500, "Scheduled func was not called")
  end

  test "skipping today before a scheduled time forces a reschedule" do
    {:ok, agent_pid} = Agent.start_link(fn -> {0, ~U[2023-05-15 09:00:00.000Z]} end)

    clock_source = fn ->
      Agent.get_and_update(
        agent_pid,
        fn
          {0, time} ->
            {time, {1, ~U[2023-05-15 09:00:00.250Z]}}

          # This is kinda weird, but we can, with some confidence, test that the
          # skip is working properly by making sure that we keep calling the clock
          # source a lot (more than we could reasonably do in a single run of the
          # scheduler), we can be sure that the skip code has actually been called
          # and advance the clock. Basically, we have no way of knowing when a skip
          # was checked, so if we just let the skip check a lot of times, and
          # eventually advance the clock, we can test that a reschedule happens.
          {n, _time} when n > 100 ->
            {~U[2023-05-16 09:00:00.000Z], {n + 1, ~U[2023-05-16 09:00:00.000Z]}}

          {n, time} ->
            {time, {n + 1, time}}
        end
      )
    end

    this_pid = self()

    schedule_func = fn ->
      stored_date = Agent.get(agent_pid, fn {_n, time} -> DateTime.to_date(time) end)
      send(this_pid, {:called, stored_date})
    end

    start_supervised!(
      {Scheduler,
       {
         [
           %{
             id: "my-timer",
             start_time: Scheduler.StartTime.next_possible(~T[09:00:00.250Z]),
             scheduled_func: schedule_func
           }
         ],
         clock_source: clock_source
       }}
    )

    # We shouldn't get "today's" reminder
    Scheduler.dont_remind_today("my-timer", ~D[2023-05-15])
    refute_receive(:called, 500, "Scheduled func was called unexpectedly")

    # ...but when we reschedule, we should get tomorrow's reminder
    assert_receive(
      {:called, ~D[2023-05-16]},
      1000,
      "Scheduled func was not called in the reschedule"
    )
  end
end
