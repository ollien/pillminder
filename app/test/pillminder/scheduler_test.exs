defmodule PillminderTest.Scheduler do
  alias Pillminder.Scheduler

  # Cannot be async, due to several processes being named as __MODULE__
  # It's a lot of plumbing to make this work asynchronously
  # TODO: add that plumbing
  use ExUnit.Case

  doctest Pillminder.Scheduler

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
         clock_source: fn -> Timex.to_datetime({{2022, 5, 15}, {9, 0, 0}}) end
       }}
    )

    assert_receive(:called, 500, "Scheduled func was not called")
  end

  test "reschedules itself to run again" do
    {:ok, times_agent_pid} =
      Agent.start_link(fn ->
        [
          # This hack is silly but because the code calls clock_source thrice, we duplicate our
          # instances of the time given
          ~U[2022-05-15 09:00:00.000Z],
          ~U[2022-05-15 09:00:00.000Z],
          ~U[2022-05-15 09:00:00.000Z],

          # Reschedule
          ~U[2022-05-16 09:00:00.000Z],
          ~U[2022-05-16 09:00:00.000Z],
          ~U[2022-05-16 09:00:00.000Z]
        ]
      end)

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
         clock_source: fn ->
           Agent.get_and_update(times_agent_pid, fn [next | rest] -> {next, rest} end)
         end
       }}
    )

    assert_receive(:called, 500, "Scheduled func was not called")
    assert_receive(:called, 1000, "Scheduled func was not called a second time")
  end

  test "a crashing task is still rescheduled" do
    {:ok, times_agent_pid} =
      Agent.start_link(fn ->
        [
          # This hack is silly but because the code calls clock_source thrice, we duplicate our
          # instances of the time given
          ~U[2022-05-15 09:00:00.000Z],
          ~U[2022-05-15 09:00:00.000Z],
          ~U[2022-05-15 09:00:00.000Z],

          # Reschedule
          ~U[2022-05-16 09:00:00.000Z],
          ~U[2022-05-16 09:00:00.000Z],
          ~U[2022-05-16 09:00:00.000Z]
        ]
      end)

    this_pid = self()

    start_supervised!(
      {Scheduler,
       {
         [
           %{
             id: "my-timer",
             start_time: Scheduler.StartTime.next_possible(~T[09:00:00.250Z]),
             scheduled_func: fn ->
               send(this_pid, :called)
               :erlang.error(:deliberate_crash)
             end
           }
         ],
         clock_source: fn ->
           Agent.get_and_update(times_agent_pid, fn [next | rest] -> {next, rest} end)
         end
       }}
    )

    assert_receive(:called, 500, "Scheduled func was not called")
    assert_receive(:called, 1000, "Scheduled func was not called a second time")
  end

  test "skipping today after a scheduled time does nothing" do
    {:ok, times_agent_pid} =
      Agent.start_link(fn ->
        [
          # This hack is silly but because the code calls clock_source twice, we duplicate our
          # instances of the time given
          ~U[2023-05-15 23:59:59.750Z],
          ~U[2023-05-15 23:59:59.750Z],
          ~U[2023-05-15 23:59:59.750Z],

          # For the rescheduling; follows the same hack as before
          ~U[2023-05-16 00:00:00.000Z],
          ~U[2023-05-16 00:00:00.000Z],
          ~U[2023-05-16 00:00:00.000Z]
        ]
      end)

    this_pid = self()

    start_supervised!(
      {Scheduler,
       {
         [
           %{
             id: "my-timer",
             start_time: Scheduler.StartTime.next_possible(~T[00:00:00.000Z]),
             scheduled_func: fn -> send(this_pid, :called) end
           }
         ],
         clock_source: fn ->
           Agent.get_and_update(times_agent_pid, fn [next | rest] -> {next, rest} end)
         end
       }}
    )

    # its currently 23:59:59.750, so today's reminder has already gone off (at 00:00:00).
    # We want to make sure the reminder at 00:00:00 (the next day) still goes off
    Scheduler.dont_remind_today("my-timer", ~D[2023-05-15])
    assert_receive(:called, 500, "Scheduled func was not called")
  end

  test "skipping today before a scheduled time forces a reschedule" do
    {:ok, times_agent_pid} =
      Agent.start_link(fn ->
        [
          # This hack is silly but because the code calls clock_source twice, we duplicate our
          # instances of the time given
          ~U[2023-05-15 09:00:00.000Z],
          ~U[2023-05-15 09:00:00.000Z],
          ~U[2023-05-15 09:00:00.000Z],

          # For the rescheduling; follows the same hack as before
          ~U[2023-05-16 08:59:59.500Z],
          ~U[2023-05-16 08:59:59.500Z],
          ~U[2023-05-16 08:59:59.500Z]
        ]
      end)

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
         clock_source: fn ->
           Agent.get_and_update(times_agent_pid, fn [next | rest] -> {next, rest} end)
         end
       }}
    )

    # We shouldn't get "today's" reminder
    Scheduler.dont_remind_today("my-timer", ~D[2023-05-15])
    refute_receive(:called, 500, "Scheduled func was called unexpectedly")

    # ...but when we reschedule, we should get tomorrow's reminder
    # We "cleverly" advanced the clock during the reschedule to 08:59:59.500, so it will take 750 ms to get this sent.
    assert_receive(:called, 1000, "Scheduled func was not called in the reschedule")
  end
end
