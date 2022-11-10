defmodule Pillminder.Application do
  alias Pillminder.ReminderServer
  alias Pillminder.Config

  use Application

  @interval_ms 5000

  @impl true
  def start(_type, _args) do
    timers = Config.load_timers_from_env!()
    timer_specs = Enum.map(timers, &make_spec_for_timer/1)

    children =
      timer_specs ++
        [
          # # TODO: Add port to config file
          {Plug.Cowboy, scheme: :http, plug: Pillminder.WebRouter, options: [port: 8000]}
        ]

    {:ok, supervisor_pid} =
      Supervisor.start_link(children, strategy: :one_for_one, name: Pillminder.Supervisor)

    # TODO: Replace this with the appropriate configuration property
    :ok = Pillminder.send_reminders(@interval_ms)

    {:ok, supervisor_pid}
  end

  @spec make_spec_for_timer(Config.Timer) :: {module(), term()}
  defp make_spec_for_timer(timer) do
    {ReminderServer,
     fn ->
       Pillminder.Ntfy.push_notification(timer.ntfy_topic, %{
         title: "this is a test for timer id #{timer.id}"
       })
     end}
  end
end
