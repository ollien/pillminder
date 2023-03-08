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
    http_server_opts = http_server_opts!()

    children = [
      Pillminder.Stats.Repo,
      {Pillminder.ReminderSender, make_senders_for_timers(timers)},
      {Scheduler, make_scheduler_args(timers)},
      Pillminder.Auth,
      {Plug.Cowboy, scheme: :http, plug: Pillminder.WebRouter, options: http_server_opts}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Pillminder.Supervisor)
  end

  @spec http_server_opts!() :: [port: number(), ip: :inet.ip_address()]
  defp http_server_opts!() do
    server_config = Config.load_server_settings_from_env!()

    {:ok, listen_addr} =
      server_config.listen_addr
      |> String.to_charlist()
      |> :inet.parse_address()

    Logger.info("Starting HTTP server on port #{server_config.listen_addr}:#{server_config.port}")
    [port: server_config.port, ip: listen_addr]
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
      Logger.debug("Sending reminder notification for #{timer.id}")

      case Pillminder.Notifications.send_reminder_notification(timer.id) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to send reminder notification for #{timer.id}: #{reason}")
      end
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
      id: timer.id,
      start_time:
        Scheduler.StartTime.next_possible_with_fudge(
          timer.reminder_start_time,
          timer.reminder_start_time_fudge
        ),
      time_zone: timer.reminder_time_zone,
      scheduled_func: fn ->
        # The task supervisor in the Scheduler should re-run this, so it's ok to assert
        # We want to make sure that we don't have two timers going at once, so we cancel an existing one, if there is.
        # (this would be possible if a day was missed)
        :ok = cancel_if_exists(timer)
        :ok = Pillminder.send_reminder_for_timer(timer)
        Logger.info("Kicked off reminder for timer starting at #{timer.reminder_start_time}")
      end
    }
  end

  @spec cancel_if_exists(Config.Timer.t()) :: :ok | {:error, any()}
  defp cancel_if_exists(timer) do
    case ReminderSender.dismiss(timer.id) do
      :ok -> :ok
      {:error, :not_timing} -> :ok
      err = {:error, _reason} -> err
    end
  end
end
