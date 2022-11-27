defmodule PillminderTest.ReminderSender do
  alias Pillminder.ReminderSender

  use ExUnit.Case, async: true
  doctest Pillminder.ReminderSender

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

    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})

    :ok = ReminderSender.send_reminder_on_interval("reminder", 50)

    refute_receive(:called, 40)
    # Imperfect, but by calling multiple times we can assume we are being called on an interval
    assert_receive(:called, 100)
    assert_receive(:called, 100)
    assert_receive(:called, 100)
  end

  test "can remind on interval and send immediately" do
    proc = self()

    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})

    :ok = ReminderSender.send_reminder_on_interval("reminder", 50, send_immediately: true)

    assert_receive(:called, 40)
    # Imperfect, but by calling multiple times we can assume we are being called on an interval
    assert_receive(:called, 100)
    assert_receive(:called, 100)
    assert_receive(:called, 100)
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
    {:error, :no_timer} = ReminderSender.dismiss("reminder")
  end

  test "continues to send interval reminder even if SendServer crashes" do
    proc = self()

    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})
    :ok = ReminderSender.send_reminder_on_interval("reminder", 50, send_immediately: true)

    pid = ReminderSender._get_current_send_server_pid("reminder")
    assert pid != nil, "SendServer with expected name was nto found"

    # Kill the process to simulate a crash
    Process.exit(pid, :kill)

    # Imperfect, but by calling multiple times we can assume we are being called on an interval
    assert_receive(:called, 100)
    assert_receive(:called, 100)
    assert_receive(:called, 100)
  end

  test "can cancel interval reminder even if SendServer crashes" do
    proc = self()

    start_supervised!({ReminderSender, %{"reminder" => fn -> send(proc, :called) end}})
    :ok = ReminderSender.send_reminder_on_interval("reminder", 100, send_immediately: true)

    pid = ReminderSender._get_current_send_server_pid("reminder")
    assert pid != nil, "SendServer with expected name was nto found"

    # Kill the process to simulate a crash
    Process.exit(pid, :kill)

    dismiss_task =
      Task.async(fn ->
        retry_until_alive(fn -> ReminderSender.dismiss("reminder") end)
      end)

    :ok = Task.await(dismiss_task)

    # Imperfect, but by calling multiple times we can assume we are being called on an interval
    refute_receive(:called, 200)
  end

  defp retry_until_alive(func) do
    try do
      func.()
    catch
      :exit, {:noproc, _} -> retry_until_alive(func)
    end
  end
end
