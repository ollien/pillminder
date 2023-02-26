defmodule PillminderTest.Scheduler.StartTime do
  alias Pillminder.Scheduler.StartTime
  use ExUnit.Case, async: true

  doctest Pillminder.Scheduler.StartTime

  describe "next_possible_with_fudge" do
    test "gets time within random range" do
      now = Timex.to_datetime({{2022, 1, 1}, {1, 0, 0}}, "America/New_York")

      start_time = ~T[13:37:00]
      start_time_func = StartTime.next_possible_with_fudge(start_time, 3600)

      unique_vals =
        Enum.map(1..100, fn _ ->
          {:ok, schedule_time} = start_time_func.(now)
          Timex.diff(schedule_time, now, :duration) |> Timex.Duration.to_seconds()
        end)
        |> Enum.into(MapSet.new())

      assert(
        MapSet.size(unique_vals) > 1,
        "There were no unique values in the list of generated times"
      )
    end

    test "passing a zero fudge is equivalent to just calling next_possible" do
      now = Timex.to_datetime({{2022, 1, 1}, {1, 0, 0}}, "America/New_York")

      start_time = ~T[13:37:00]

      assert StartTime.next_possible_with_fudge(start_time, 0).(now) ==
               StartTime.next_possible(start_time).(now)
    end
  end
end
