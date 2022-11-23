defmodule Pillminder.Application do
  require Logger

  alias Pillminder.Scheduler
  alias Pillminder.ReminderSender
  alias Pillminder.Config

  use Application

  @registry_name ReminderSender.Registry

  @impl true
  def start(_type, _args) do
    timers = Config.load_timers_from_env!()
    timer_specs = Enum.map(timers, &make_reminder_sender_spec/1)

    children =
      [{Registry, keys: :unique, name: @registry_name}] ++
        timer_specs ++
        [
          {Scheduler, make_scheduler_args(timers)},
          # # TODO: Add port to config file
          {Plug.Cowboy, scheme: :http, plug: Pillminder.WebRouter, options: [port: 8000]}
        ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Pillminder.Supervisor)
  end

  @spec reminder_sender_registry() :: module
  def reminder_sender_registry(), do: @registry_name

  @spec reminder_sender_via_tuple(Config.Timer) :: {:via, module(), {term(), term()}}
  def reminder_sender_via_tuple(timer) do
    {:via, Registry, {ReminderSender.Registry, make_reminder_sender_id(timer)}}
  end

  @spec make_reminder_sender_spec(Config.Timer) :: Supervisor.child_spec()
  defp make_reminder_sender_spec(timer) do
    Supervisor.child_spec(
      {
        ReminderSender,
        {fn ->
           Logger.debug("Sending notification request to ntfy for #{timer.id}")

           {:ok, resp} =
             Pillminder.Ntfy.push_notification(
               timer.ntfy_topic,
               Pillminder.make_notification_body(timer)
             )

           Logger.debug("Got response from ntfy: #{inspect(resp)}")
         end, name: reminder_sender_via_tuple(timer)}
      },
      id: make_reminder_sender_id(timer)
    )
  end

  @spec make_scheduler_args([Config.Timer.t()]) ::
          {[Scheduler.scheduled_reminder()], Scheduler.init_options()}
  defp make_scheduler_args(timers) do
    {
      Enum.map(timers, &make_reminder_for_scheduler/1),
      []
    }
  end

  @spec make_reminder_for_scheduler(Config.Timer.t()) :: Scheduler.scheduled_reminder()
  defp make_reminder_for_scheduler(timer) do
    %{
      start_time: timer.reminder_start_time,
      scheduled_func: fn ->
        # The task supervisor in the Scheduler should re-run this, so it's ok to assert
        :ok = Pillminder.send_reminder_for_timer(timer)
        Logger.debug("Sent reminder for timer starting at #{timer.reminder_start_time}")
      end
    }
  end

  @spec make_reminder_sender_id(Config.Timer) :: String.t()
  def make_reminder_sender_id(timer = %Config.Timer{}) do
    make_reminder_sender_id(timer.id)
  end

  @spec make_reminder_sender_id(String.t()) :: String.t()
  def make_reminder_sender_id(name) do
    "ReminderSender:#{name}"
  end
end
