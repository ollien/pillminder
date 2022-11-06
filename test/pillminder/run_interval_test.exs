defmodule PillminderTest.RunInterval do
  alias Pillminder.RunInterval

  use ExUnit.Case
  doctest Pillminder.RunInterval

  test "passes the time waited to the called function" do
    proc = self()
    interval = 10

    RunInterval.apply_interval(interval, fn timeout -> send(proc, timeout) end)

    assert_receive(^interval, 100)
  end

  test "calls target function repeatedly" do
    proc = self()
    interval = 10

    RunInterval.apply_interval(interval, fn timeout -> send(proc, timeout) end)

    # Ideally this would assert the time between, but that's going to be brittle
    # for scheduling reasons. Checking that we got a few calls is good enough, I think.
    assert_receive(_, 100)
    assert_receive(_, 100)
    assert_receive(_, 100)
  end
end
