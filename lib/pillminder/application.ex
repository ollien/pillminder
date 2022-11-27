defmodule Pillminder.Application do
  require Logger

  alias Pillminder.ReminderSender.SendServer
  alias Pillminder.Scheduler
  alias Pillminder.ReminderSender
  alias Pillminder.Config

  use Application

  @impl true
  def start(_type, _args) do
    timers = Config.load_timers_from_env!()

    children = [
      # TODO: Start new reminder sender here
      {Pillminder.ReminderSender, make_senders_for_timers(timers)},
      {Scheduler, make_scheduler_args(timers)},
      # # TODO: Add port to config file
      {Plug.Cowboy, scheme: :http, plug: Pillminder.WebRouter, options: [port: 8000]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Pillminder.Supervisor)
  end

  @spec make_senders_for_timers([Config.Timer.t()]) :: ReminderSender.senders()
  defp make_senders_for_timers(timers) do
    Enum.map(timers, &make_sender_for_timer/1) |> Map.new()
  end

  @spec make_sender_for_timer(Config.Timer.t()) ::
          {ReminderSender.sender_id(), SendServer.remind_func()}
  defp make_sender_for_timer(timer) do
    {timer.id, make_remind_func_for_timer(timer)}
  end

  @spec make_remind_func_for_timer(Config.Timer.t()) :: SendServer.remind_func()
  defp make_remind_func_for_timer(timer) do
    fn ->
      Logger.debug("Sending notification request to ntfy for #{timer.id}")

      {:ok, resp} =
        Pillminder.Ntfy.push_notification(
          timer.ntfy_topic,
          Pillminder.make_notification_body(timer)
        )

      Logger.debug("Got response from ntfy: #{inspect(resp)}")
    end
  end

  @spec make_scheduler_args([Config.Timer.t()]) ::
          {[Scheduler.ScheduledReminder.t()], Scheduler.init_options()}
  defp make_scheduler_args(timers) do
    {
      Enum.map(timers, &make_reminder_for_scheduler/1),
      []
    }
  end

  @spec make_reminder_for_scheduler(Config.Timer.t()) :: Scheduler.ScheduledReminder.t()
  defp make_reminder_for_scheduler(timer) do
    %Scheduler.ScheduledReminder{
      start_time: timer.reminder_start_time,
      scheduled_func: fn ->
        # The task supervisor in the Scheduler should re-run this, so it's ok to assert
        :ok = Pillminder.send_reminder_for_timer(timer)
        Logger.debug("Sent reminder for timer starting at #{timer.reminder_start_time}")
      end
    }
  end
end
