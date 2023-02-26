defmodule PillminderTest.ReminderSender do
  alias Pillminder.ReminderSender

  use ExUnit.Case, async: true
  doctest Pillminder.ReminderSender

  # Imperfect, but by calling multiple times we can assume we are being called on an interval
  defmacro assert_receive_on_interval(msg, delay, n \\ 3) do
    quote do
      1..unquote(n)
      |> Enum.each(fn _iteration ->
        assert_receive(unquote(msg), unquote(delay))
      end)
    end
  end

  test "calls target function when send_reminder is called" do
    {:ok, called_agent} = Agent.start_link(fn -> false end)

    start_supervised!(
      {ReminderSender, %{"reminder" => fn -> Agent.update(called_agent, fn _ -> true end) end}}
    )

    {:ok, :ok} = ReminderSender.send_reminder("reminder")
    was_called = Agent.get(called_agent, & &1)
    assert was_called
  end

  test "retries sending when the task crashes" do
    {:ok, should_crash_agent} = Agent.start_link(fn -> true end)
    {:ok, called_agent} = Agent.start_link(fn -> false end)

    start_supervised!({ReminderSender,
     %{
       "reminder" => fn ->
         # On the first call, this will fail and we will crash deliberately
         if Agent.get_and_update(should_crash_agent, fn value -> {value, false} end) do
           :erlang.error(:deliberate_crash)
         end

         # On the second call, the :erlang.error should not occur and we will mark called as true
         Agent.update(called_agent, fn _ -> true end)
       end
     }})

    {:ok, :ok} = ReminderSender.send_reminder("reminder")
    was_called = Agent.get(called_agent, & &1)
    assert was_called
  end

  test "can remind on interval" do
    proc = self()
    interval = 50
    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})

    :ok = ReminderSender.send_reminder_on_interval("reminder", interval)

    refute_receive(:called, interval - 10)
    assert_receive_on_interval(:called, interval * 2)
  end

  test "can remind on interval and send immediately" do
    proc = self()
    interval = 50
    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})

    :ok = ReminderSender.send_reminder_on_interval("reminder", interval, send_immediately: true)

    assert_receive(:called, interval - 10)
    assert_receive_on_interval(:called, interval * 2)
  end

  test "can not start interval twice" do
    proc = self()

    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})

    :ok = ReminderSender.send_reminder_on_interval("reminder", 50)
    {:error, :already_timing} = ReminderSender.send_reminder_on_interval("reminder", 50)
  end

  test "can cancel timer" do
    proc = self()
    interval = 50
    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})

    :ok = ReminderSender.send_reminder_on_interval("reminder", interval)

    assert_receive(:called, interval * 2)
    :ok = ReminderSender.dismiss("reminder")
    refute_receive(:called, interval * 2)
  end

  test "cannot cancel when timer is not running" do
    start_supervised!({ReminderSender, %{"reminder" => fn -> nil end}})
    {:error, :not_timing} = ReminderSender.dismiss("reminder")
  end

  test "snooze will delay interval reminders for the given amount of time" do
    proc = self()
    interval = 50
    snooze_time = interval * 2
    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})
    :ok = ReminderSender.send_reminder_on_interval("reminder", interval)
    :ok = ReminderSender.snooze("reminder", snooze_time)

    refute_receive(:called, interval * 2 - 10)

    # After the snooze, we should get repeated reminders
    # We should get one fairly immediately after the snooze timer ends
    assert_receive(:called, snooze_time)
    assert_receive_on_interval(:called, interval * 2)
  end

  test "snoozing twice will take the latter of the two lengths" do
    proc = self()
    interval = 100
    snooze_time = div(interval, 2)
    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})

    :ok = ReminderSender.send_reminder_on_interval("reminder", interval)
    :ok = ReminderSender.snooze("reminder", 10000)
    :ok = ReminderSender.snooze("reminder", snooze_time)

    refute_receive(:called, snooze_time - 10)

    # After the snooze, we should get repeated reminders
    # We should get one fairly immediately after the snooze timer ends
    assert_receive(:called, snooze_time)
    assert_receive_on_interval(:called, interval * 2)
  end

  test "cannot snooze with no running timer" do
    start_supervised!({ReminderSender, %{"reminder" => fn -> nil end}})
    {:error, :not_timing} = ReminderSender.snooze("reminder", 1000)
  end

  test "can cancel a snoozed timer" do
    proc = self()
    interval = 50
    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})
    :ok = ReminderSender.send_reminder_on_interval("reminder", interval)
    :ok = ReminderSender.snooze("reminder", interval)
    :ok = ReminderSender.dismiss("reminder")

    refute_receive(:called, interval * 2)
  end

  test "continues to send interval reminder even if SendServer crashes" do
    proc = self()
    interval = 50
    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})
    :ok = ReminderSender.send_reminder_on_interval("reminder", interval, send_immediately: true)

    pid = ReminderSender._get_current_send_server_pid("reminder")
    assert pid != nil, "SendServer with expected name was nto found"

    # Kill the process to simulate a crash
    Process.exit(pid, :kill)

    assert_receive_on_interval(:called, interval * 2)
  end

  test "can cancel interval reminder even if SendServer crashes" do
    proc = self()
    interval = 100
    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})
    :ok = ReminderSender.send_reminder_on_interval("reminder", interval, send_immediately: true)

    pid = ReminderSender._get_current_send_server_pid("reminder")
    assert pid != nil, "SendServer with expected name was nto found"

    # Kill the process to simulate a crash
    Process.exit(pid, :kill)

    dismiss_task =
      Task.async(fn ->
        retry_until_alive(fn -> ReminderSender.dismiss("reminder") end)
      end)

    :ok = Task.await(dismiss_task)

    refute_receive(:called, interval * 2)
  end

  test "does not crash for a non-existent sender" do
    start_supervised!({ReminderSender, %{"reminder" => fn -> nil end}})

    assert ReminderSender.send_reminder("non-existent") == {:error, :no_timer}
    assert ReminderSender.send_reminder_on_interval("non-existent", 100) == {:error, :no_timer}
    assert ReminderSender.dismiss("non-existent") == {:error, :no_timer}
    assert ReminderSender.snooze("non-existent", 1000) == {:error, :no_timer}
  end

  defp retry_until_alive(func) do
    case func.() do
      {:error, :no_timer} -> retry_until_alive(func)
      val -> val
    end
  end
end
