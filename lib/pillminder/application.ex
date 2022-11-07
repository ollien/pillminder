defmodule Pillminder.Application do
  alias Pillminder.ReminderServer

  # 5 * 60 * 60
  @interval_ms 5000

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ReminderServer,
       fn ->
         Pillminder.Ntfy.push_notification(
           Application.fetch_env!(:pillminder, :ntfy_topic),
           %{title: "this is a test"}
         )
       end}
    ]

    {:ok, supervisor_pid} =
      Supervisor.start_link(children, strategy: :one_for_one, name: Pillminder.Supervisor)

    :ok = Pillminder.send_reminders(@interval_ms)

    {:ok, supervisor_pid}
  end
end
