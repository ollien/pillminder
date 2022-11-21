defmodule PillminderTest.ReminderServer do
  alias Pillminder.ReminderServer

  use ExUnit.Case, async: true
  doctest Pillminder.ReminderServer

  test "calls target function when send_reminder is called" do
    {:ok, called_agent} = Agent.start_link(fn -> false end)
    start_supervised!({ReminderServer, {fn -> Agent.update(called_agent, fn _ -> true end) end}})
    :ok = ReminderServer.send_reminder()
    was_called = Agent.get(called_agent, & &1)
    assert was_called
  end

  test "can remind on interval" do
    proc = self()

    start_supervised!({ReminderServer, {fn -> send(proc, :called) end}})

    :ok = ReminderServer.send_reminder_on_interval(50)

    # Imperfect, but by calling multiple times we can assume we are being called on an interval
    assert_receive(:called, 100)
    assert_receive(:called, 100)
    assert_receive(:called, 100)
  end

  # TODO: this could maybe be a parametrized test, but I don't want to pull in a library for that just yet
  test "can remind on interval with custom server name" do
    proc = self()

    start_supervised!({ReminderServer, {fn -> send(proc, :called) end, name: :remind_me}})

    :ok = ReminderServer.send_reminder_on_interval(50, server_name: :remind_me)

    # Imperfect, but by calling multiple times we can assume we are being called on an interval
    assert_receive(:called, 100)
    assert_receive(:called, 100)
    assert_receive(:called, 100)
  end

  test "can not start interval twice" do
    proc = self()

    start_supervised!({ReminderServer, {fn -> send(proc, :called) end}})

    :ok = ReminderServer.send_reminder_on_interval(50)
    {:error, :already_timing} = ReminderServer.send_reminder_on_interval(50)
  end

  test "can cancel timer" do
    proc = self()
    interval = 50

    start_supervised!({ReminderServer, {fn -> send(proc, :called) end}})
    :ok = ReminderServer.send_reminder_on_interval(interval)

    assert_receive(:called, 100)
    :ok = ReminderServer.dismiss()
    assert_not_received_after(:called, interval)
  end

  test "cannot cancel when timer is not running" do
    start_supervised!({ReminderServer, {fn -> nil end}})
    {:error, :no_timer} = ReminderServer.dismiss()
  end

  defp assert_not_received_after(to_match, timeout) do
    receive do
    after
      timeout -> refute_receive(^to_match)
    end
  end
end
