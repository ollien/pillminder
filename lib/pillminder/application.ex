defmodule Pillminder.Application do
  alias Pillminder.ReminderServer

  @interval_ms 5 * 60 * 60

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ReminderServer, &print/0}
    ]

    {:ok, supervisor_pid} =
      Supervisor.start_link(children, strategy: :one_for_one, name: Pillminder.Supervisor)

    :ok = Pillminder.send_reminders(@interval_ms)

    {:ok, supervisor_pid}
  end

  defp print() do
    IO.puts("Would send reminder...")
  end
end
