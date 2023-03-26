defmodule PillminderTest.Scheduler.SkipDate do
  alias Pillminder.Scheduler.ScheduledReminder
  alias Pillminder.Scheduler.StartTime
  alias Pillminder.Scheduler.SkipDate

  use ExUnit.Case, async: true
  doctest Pillminder.Scheduler.SkipDate

  @today ~D[2023-03-25]
  @now ~U[2023-03-25 12:00:00Z]

  setup do
    clock_source = fn -> @now end

    start_supervised!({
      SkipDate,
      {
        [
          %ScheduledReminder{
            id: "my-timer",
            start_time: StartTime.next_possible(~T[09:00:00]),
            time_zone: :utc,
            scheduled_func: fn -> :ok end
          }
        ],
        clock_source: clock_source
      }
    })

    :ok
  end

  test "by default a date is marked as not skipped" do
    date = ~D[2023-03-25]
    assert not SkipDate.is_skipped("my-timer", date)
  end

  test "can store whether or not a date is skipped" do
    date = ~D[2023-03-25]
    :ok = SkipDate.skip_date("my-timer", date)
    assert SkipDate.is_skipped("my-timer", date)
  end

  test "storing two dates will take the latter" do
    date1 = ~D[2023-03-25]
    date2 = ~D[2023-03-26]
    :ok = SkipDate.skip_date("my-timer", date1)
    :ok = SkipDate.skip_date("my-timer", date2)

    assert not SkipDate.is_skipped("my-timer", date1)
    assert SkipDate.is_skipped("my-timer", date2)
  end

  test "skipping with no specified date will use the clock source" do
    :ok = SkipDate.skip_date("my-timer")
    assert SkipDate.is_skipped("my-timer", @today)
  end

  test "skipping a non-existent timer gives not found" do
    assert SkipDate.skip_date("some-other-timer") == {:error, :no_such_timer}
  end

  test "skipping a non-existent timer with a specific date gives not found" do
    assert SkipDate.skip_date("some-other-timer", ~D[2023-03-25]) == {:error, :no_such_timer}
  end
end
