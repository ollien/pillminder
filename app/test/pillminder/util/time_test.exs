defmodule PillminderTest.Util.Time do
  alias Pillminder.Util

  use ExUnit.Case, async: true
  doctest Pillminder.Util.Time

  describe "get_next_occurrence_of_time" do
    test "can get next instance of time before its happened" do
      now = Timex.to_datetime({{2022, 1, 1}, {1, 0, 0}}, "America/New_York")
      next_occurrence = Util.Time.get_next_occurrence_of_time(now, ~T[13:37:00])

      assert Timex.equal?(
               next_occurrence,
               Timex.to_datetime({{2022, 1, 1}, {13, 37, 0}}, "America/New_York")
             )
    end

    test "can get next instance of time after its happened" do
      now = Timex.to_datetime({{2022, 1, 1}, {14, 0, 0}}, "America/New_York")
      next_occurrence = Util.Time.get_next_occurrence_of_time(now, ~T[13:37:00])

      assert Timex.equal?(
               next_occurrence,
               Timex.to_datetime({{2022, 1, 2}, {13, 37, 0}}, "America/New_York")
             )
    end

    test "picks the next best time when time is on the daylight savings boundary when springing forward" do
      # 2022-03-13 is a DST crossover day
      now = Timex.to_datetime({{2022, 3, 13}, {1, 0, 0}}, "America/New_York")
      next_occurrence = Util.Time.get_next_occurrence_of_time(now, ~T[02:00:00])

      assert Timex.equal?(
               next_occurrence,
               Timex.to_datetime({{2022, 3, 13}, {3, 0, 0}}, "America/New_York")
             )
    end

    test "picks the next best time when time is on the daylight savings boundary when falling back" do
      # 2022-11-06 is a DST crossover day
      now = Timex.to_datetime({{2022, 11, 6}, {0, 0, 0}}, "America/New_York")
      next_occurrence = Util.Time.get_next_occurrence_of_time(now, ~T[02:00:00])

      assert Timex.equal?(
               next_occurrence,
               Timex.to_datetime({{2022, 11, 6}, {1, 0, 0}}, "America/New_York").after
             )
    end

    test "picks the next best time when time is on the same day as the daylight savings boundary when springing forward" do
      # 2023-03-12 is a DST crossover day
      now = Timex.to_datetime({{2023, 3, 12}, {10, 0, 0}}, "America/New_York")
      next_occurrence = Util.Time.get_next_occurrence_of_time(now, ~T[07:00:00])

      assert Timex.equal?(
               next_occurrence,
               Timex.to_datetime({{2023, 3, 13}, {7, 0, 0}}, "America/New_York")
             )
    end

    test "picks the next best time when time is on the same day as the daylight savings boundary when falling back forward" do
      # 2022-11-06 is a DST crossover day
      now = Timex.to_datetime({{2022, 11, 6}, {10, 0, 0}}, "America/New_York")
      next_occurrence = Util.Time.get_next_occurrence_of_time(now, ~T[07:00:00])

      assert Timex.equal?(
               next_occurrence,
               Timex.to_datetime({{2022, 11, 7}, {7, 0, 0}}, "America/New_York")
             )
    end

    test "returns the later non-ambiguous time when picking the candidate for the next day when springing forward" do
      # 2022-03-13 is a DST crossover day
      now = Timex.to_datetime({{2022, 3, 12}, {13, 0, 0}}, "America/New_York")

      # It is ambiguous what time we want, since 2:00 doesn't exist; we choose 3am, as it's the closest to reality
      next_occurrence = Util.Time.get_next_occurrence_of_time(now, ~T[02:00:00])

      assert Timex.equal?(
               next_occurrence,
               Timex.to_datetime({{2022, 3, 13}, {3, 0, 0}}, "America/New_York")
             )
    end

    test "returns the earlier non-ambiguous time when picking the candidate for the next day when falling back" do
      # 2022-11-06 is a DST crossover day
      now = Timex.to_datetime({{2022, 11, 5}, {13, 0, 0}}, "America/New_York")
      # it is ambiguous whether we want 1:00 before  or after the DST cutover
      next_occurrence = Util.Time.get_next_occurrence_of_time(now, ~T[01:00:00])

      assert Timex.equal?(
               next_occurrence,
               Timex.to_datetime({{2022, 11, 6}, {1, 0, 0}}, "America/New_York").before
             )
    end
  end
end
