defmodule Pillminder.WebRouter.Timer do
  require Logger

  alias Pillminder.Scheduler
  alias Pillminder.Config
  alias Pillminder.Stats
  alias Pillminder.Util
  alias Pillminder.ReminderSender
  alias Pillminder.WebRouter.Helper

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  @taken_param "taken"
  @snooze_time_param "snooze_time"
  @default_snooze_time Timex.Duration.from_hours(1)
                       |> Timex.Duration.to_milliseconds(truncate: true)
  @max_snooze_time Timex.Duration.from_hours(3) |> Timex.Duration.to_milliseconds(truncate: true)

  delete "/:timer_id" do
    Helper.Auth.authorize_request(conn, timer_id)

    conn = fetch_query_params(conn)

    with {:ok, params} <- parse_mark_taken_query_params(conn.query_params),
         taken = Map.get(params, "taken", true),
         _ =
           do_if(not taken, fn ->
             Logger.info(
               "#{timer_id} will be marked as not taken, and its timers skipped for today"
             )
           end),
         :ok <- dismiss_timer(timer_id),
         :ok <- do_if(taken, fn -> record_taken(timer_id) end),
         :ok <- skip_other_timers_today(timer_id) do
      send_resp(conn, 200, "{}")
    else
      {:error, {:invalid_param, reason, {param, _}}} ->
        msg = ~s(Invalid value for query parameter "#{param}": #{reason})
        Logger.debug(msg)
        send_resp(conn, 400, %{error: msg} |> Poison.encode!())

      {:error, {stage, _reason}} ->
        # Dialyzer doesn't like handling our stages in multiple with clauses here,
        # so I use this map to get around the limitation
        #
        # https://dev.to/lasseebert/til-understanding-dialyzer-s-the-pattern-can-never-match-the-type-2mmm
        err_msgs = %{
          dismiss: "Failed to dismiss timer",
          recording: "Failed to record medication as taken, but timer was dismissed.",
          skip:
            "Failed finalize timer dismissal; medication is marked as taken, but duplicate notifications may appear."
        }

        msg = Map.get(err_msgs, stage, "Unknown error ocurred during timer dismissal")

        send_resp(conn, 500, %{error: msg} |> Poison.encode!())
    end
  end

  post "/:timer_id/snooze" do
    Helper.Auth.authorize_request(conn, timer_id)

    conn = fetch_query_params(conn)

    with {:ok, params} <- parse_snooze_query_params(conn.query_params),
         snooze_ms = Map.get(params, @snooze_time_param),
         :ok <- ReminderSender.snooze(timer_id, snooze_ms) do
      minutes_until = fn ->
        Timex.Duration.from_milliseconds(snooze_ms)
        |> Timex.Duration.to_minutes()
        |> (&:io_lib.format("~.2f", [&1])).()
      end

      Logger.info("Cleared snoozed timer id #{timer_id} for #{minutes_until.()}")
      send_resp(conn, 200, "{}")
    else
      {:error, {:invalid_param, reason, {param, _}}} ->
        msg = ~s(Invalid value for query parameter "#{param}": #{reason})
        Logger.debug(msg)
        send_resp(conn, 400, %{error: msg} |> Poison.encode!())

      {:error, :not_timing} ->
        send_resp(
          conn,
          409,
          %{error: "Timer is not currently running, cannot snooze."} |> Poison.encode!()
        )

      {:error, :no_timer} ->
        msg = Helper.Response.not_found(timer_id)
        send_resp(conn, 404, %{error: msg} |> Poison.encode!())
    end
  end

  match _ do
    send_resp(conn, 404, "{}")
  end

  @spec dismiss_timer(String.t()) :: :ok | {:error, {:dismiss, any()}}
  defp dismiss_timer(timer_id) do
    case ReminderSender.dismiss(timer_id) do
      :ok ->
        Logger.info("Cleared timer id #{timer_id}")
        :ok

      {:error, :not_timing} ->
        Logger.debug("Attempted to dismiss timer id #{timer_id} but no timers are running")
        # If you dismiss something before it starts, that's fine.
        :ok

      {:error, reason} ->
        Logger.error("Failed to dismiss timer with id #{timer_id}: #{inspect(reason)}")
        {:error, {:dismiss, reason}}
    end
  end

  defp skip_other_timers_today(timer_id) do
    case Scheduler.dont_remind_today(timer_id) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to ensure today's timers would be stopped for #{timer_id}; duplicate reminders may appear: #{inspect(reason)}"
        )

        {:error, {:skip, reason}}
    end
  end

  @spec(record_taken(String.t()) :: :ok, {:error, {:recording, any()}})
  defp record_taken(timer_id) do
    with {:ok, tz} <- get_tz_for_timer(timer_id),
         now = Util.Time.now!(tz),
         :ok <- Stats.record_taken(timer_id, now) do
      Logger.info("Recorded medication for #{timer_id} as taken today")
      :ok
    else
      {:error, :already_taken_today} ->
        Logger.warning("Medication marked as taken for #{timer_id} already today.")

        # I don't think we need to fail this endpoint necessarily, but we should definitely log about it.
        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to record medication as taken timer with id #{timer_id}: #{inspect(reason)}"
        )

        {:error, {:recording, reason}}
    end
  end

  @spec parse_mark_taken_query_params(%{String.t() => String.t()}) ::
          {:ok, %{String.t() => any()}}
          | {:error, {atom, String.t(), {String.t(), String.t()}}}
  defp parse_mark_taken_query_params(params = %{}) do
    parse_single_param(params, @taken_param, fn
      nil -> {:ok, true}
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      taken_value -> {:error, {:invalid_param, "invalid boolean", {@taken_param, taken_value}}}
    end)
  end

  @spec parse_snooze_query_params(%{String.t() => String.t()}) ::
          {:ok, %{String.t() => any()}}
          | {:error, {atom, String.t(), {String.t(), String.t()}}}
  defp parse_snooze_query_params(params = %{}) do
    parse_single_param(params, @snooze_time_param, &parse_snooze_time_param/1)
  end

  defp parse_snooze_time_param(nil) do
    {:ok, @default_snooze_time}
  end

  defp parse_snooze_time_param(snooze_time_param) do
    case Integer.parse(snooze_time_param) do
      {snooze_time, ""} when snooze_time > 0 and snooze_time <= @max_snooze_time ->
        {:ok, snooze_time}

      {_snooze_time, ""} ->
        {:error,
         {:invalid_param, "must be between 1 and #{@max_snooze_time}",
          {@snooze_time_param, snooze_time_param}}}

      _ ->
        {:error, {:invalid_param, "invalid integer", {@snooze_time_param, snooze_time_param}}}
    end
  end

  @spec parse_single_param(
          params :: %{String.t() => String.t()},
          param_name :: String.t(),
          convert_func :: (String.t() | nil -> {:ok, any()} | {:error, any()})
        ) ::
          {:ok, %{String.t() => any()}}
          | {:error, {atom, String.t(), {String.t(), String.t()}}}
  defp parse_single_param(params = %{}, param_name, parse_func) do
    with {:ok, value} <- Util.QueryParam.get_value(params, param_name),
         {:ok, parsed} <- parse_func.(value) do
      parsed_params = Map.put(params, param_name, parsed)
      {:ok, parsed_params}
    else
      {:error, :not_scalar} ->
        {:error, {:invalid_param, "must be a string", {param_name, Map.get(params, param_name)}}}

      err = {:error, _reason} ->
        err
    end
  end

  @spec(
    get_tz_for_timer(String.t()) :: {:ok, Timex.Types.valid_timezone()},
    {:error, :no_such_timer}
  )
  defp get_tz_for_timer(timer_id) do
    # This can technically fail but that's fine; it almost certainly won't after application load
    Config.load_timers_from_env!()
    |> Enum.find(fn timer -> timer.id == timer_id end)
    |> case do
      nil -> {:error, :no_such_timer}
      %Config.Timer{reminder_time_zone: zone} -> {:ok, zone}
    end
  end

  @spec do_if(boolean, (-> t)) :: :ok | t when t: any
  defp do_if(true, func) do
    func.()
  end

  defp do_if(false, _func) do
    :ok
  end
end
