defmodule PillminderTest.Scheduler do
  alias Pillminder.Scheduler

  use ExUnit.Case
  doctest Pillminder.Scheduler

  test "runs task at specified time" do
    this_pid = self()

    start_supervised!(
      {Scheduler,
       {
         [
           %{
             start_time: ~T[09:00:00.250Z],
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
          {{2022, 5, 15}, {9, 0, 0}},
          {{2022, 5, 16}, {9, 0, 0}}
        ]
      end)

    this_pid = self()

    start_supervised!(
      {Scheduler,
       {
         [
           %{
             start_time: ~T[09:00:00.250Z],
             scheduled_func: fn -> send(this_pid, :called) end
           }
         ],
         clock_source: fn ->
           time = Agent.get_and_update(times_agent_pid, fn [next | rest] -> {next, rest} end)
           Timex.to_datetime(time)
         end
       }}
    )

    assert_receive(:called, 500, "Scheduled func was not called")
    assert_receive(:called, 1000, "Scheduled func was not called a second time")
  end
end
