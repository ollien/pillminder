defmodule PillminderTest.ReminderSender do
  alias Pillminder.ReminderSender

  use ExUnit.Case, async: true
  doctest Pillminder.ReminderSender

  test "calls target function when send_reminder is called" do
    {:ok, called_agent} = Agent.start_link(fn -> false end)
    start_supervised!({ReminderSender, {fn -> Agent.update(called_agent, fn _ -> true end) end}})
    {:ok, :ok} = ReminderSender.send_reminder()
    was_called = Agent.get(called_agent, & &1)
    assert was_called
  end

  test "retries sending when the task crashes" do
    {:ok, should_crash_agent} = Agent.start_link(fn -> true end)
    {:ok, called_agent} = Agent.start_link(fn -> false end)

    start_supervised!({ReminderSender,
     {fn ->
        # On the first call, this will fail and we will crash deliberately
        if Agent.get_and_update(should_crash_agent, fn value -> {value, false} end) do
          :erlang.error(:deliberate_crash)
        end

        # On the second call, the :erlang.error should not occur and we will mark called as true
        Agent.update(called_agent, fn _ -> true end)
      end}})

    {:ok, :ok} = ReminderSender.send_reminder()
    was_called = Agent.get(called_agent, & &1)
    assert was_called
  end

  test "can remind on interval" do
    proc = self()

    start_supervised!({ReminderSender, {fn -> send(proc, :called) end}})

    :ok = ReminderSender.send_reminder_on_interval(50)

    refute_receive(:called, 40)
    # Imperfect, but by calling multiple times we can assume we are being called on an interval
    assert_receive(:called, 100)
    assert_receive(:called, 100)
    assert_receive(:called, 100)
  end

  # TODO: this could maybe be a parametrized test, but I don't want to pull in a library for that just yet
  test "can remind on interval with custom server name" do
    proc = self()

    start_supervised!({ReminderSender, {fn -> send(proc, :called) end, name: :remind_me}})

    :ok = ReminderSender.send_reminder_on_interval(50, server_name: :remind_me)

    refute_receive(:called, 40)
    # Imperfect, but by calling multiple times we can assume we are being called on an interval
    assert_receive(:called, 100)
    assert_receive(:called, 100)
    assert_receive(:called, 100)
  end

  test "can remind on interval and send immediately" do
    proc = self()

    start_supervised!({ReminderSender, {fn -> send(proc, :called) end}})

    :ok = ReminderSender.send_reminder_on_interval(50, send_immediately: true)

    assert_receive(:called, 40)
    # Imperfect, but by calling multiple times we can assume we are being called on an interval
    assert_receive(:called, 100)
    assert_receive(:called, 100)
    assert_receive(:called, 100)
  end

  test "can not start interval twice" do
    proc = self()

    start_supervised!({ReminderSender, {fn -> send(proc, :called) end}})

    :ok = ReminderSender.send_reminder_on_interval(50)
    {:error, :already_timing} = ReminderSender.send_reminder_on_interval(50)
  end

  test "can cancel timer" do
    proc = self()
    interval = 50

    start_supervised!({ReminderSender, {fn -> send(proc, :called) end}})
    :ok = ReminderSender.send_reminder_on_interval(interval)

    assert_receive(:called, interval * 2)
    :ok = ReminderSender.dismiss()
    refute_receive(:called, interval * 2)
  end

  test "cannot cancel when timer is not running" do
    start_supervised!({ReminderSender, {fn -> nil end}})
    {:error, :no_timer} = ReminderSender.dismiss()
  end
end
