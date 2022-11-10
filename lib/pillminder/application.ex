defmodule Pillminder.Application do
  alias Pillminder.ReminderServer
  alias Pillminder.Config

  use Application

  @registry_name ReminderServer.Registry

  @impl true
  def start(_type, _args) do
    timers = Config.load_timers_from_env!()
    timer_specs = Enum.map(timers, &make_spec_for_timer/1)

    children =
      [{Registry, keys: :unique, name: @registry_name}] ++
        timer_specs ++
        [
          # # TODO: Add port to config file
          {Plug.Cowboy, scheme: :http, plug: Pillminder.WebRouter, options: [port: 8000]}
        ]

    {:ok, supervisor_pid} =
      Supervisor.start_link(children, strategy: :one_for_one, name: Pillminder.Supervisor)

    :ok = Pillminder.send_reminders(timers)

    {:ok, supervisor_pid}
  end

  @spec reminder_server_registry() :: module
  def reminder_server_registry(), do: @registry_name

  @spec reminder_server_via_tuple(Config.Timer) :: {:via, module(), {term(), term()}}
  def reminder_server_via_tuple(timer) do
    {:via, Registry, {ReminderServer.Registry, make_reminder_server_id(timer)}}
  end

  @spec make_spec_for_timer(Config.Timer) :: Supervisor.child_spec()
  defp make_spec_for_timer(timer) do
    Supervisor.child_spec(
      {
        ReminderServer,
        {fn ->
           Pillminder.Ntfy.push_notification(timer.ntfy_topic, %{
             title: "this is a test for timer id #{timer.id}"
           })
         end, name: reminder_server_via_tuple(timer)}
      },
      id: make_reminder_server_id(timer)
    )
  end

  @spec make_reminder_server_id(Config.Timer) :: String.t()
  defp make_reminder_server_id(timer) do
    "ReminderServer:#{timer.id}"
  end
end
