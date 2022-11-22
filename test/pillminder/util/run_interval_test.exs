defmodule PillminderTest.Util.RunInterval do
  alias Pillminder.Util.RunInterval

  use ExUnit.Case, async: true
  doctest Pillminder.Util.RunInterval

  test "calls target function repeatedly" do
    proc = self()
    interval = 10

    RunInterval.apply_interval(interval, fn -> send(proc, :data) end)

    # Ideally this would assert the time between, but that's going to be brittle
    # for scheduling reasons. Checking that we got a few calls is good enough, I think.
    assert_receive(:data, 100)
    assert_receive(:data, 100)
    assert_receive(:data, 100)
  end
end
