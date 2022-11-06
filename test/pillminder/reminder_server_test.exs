defmodule PillminderTest.ReminderServer do
  alias Pillminder.ReminderServer

  use ExUnit.Case
  doctest Pillminder.ReminderServer

  test "calls target function when send_reminder is called" do
    {:ok, called_agent} = Agent.start_link(fn -> false end)
    start_supervised!({ReminderServer, fn -> Agent.update(called_agent, fn _ -> true end) end})
    :ok = ReminderServer.send_reminder()
    was_called = Agent.get(called_agent, & &1)
    assert was_called
  end
end
