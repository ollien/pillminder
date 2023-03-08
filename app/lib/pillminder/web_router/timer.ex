defmodule Pillminder.WebRouter.Timer do
  require Logger

  alias Pillminder.Config
  alias Pillminder.Stats
  alias Pillminder.Util
  alias Pillminder.ReminderSender
  alias Pillminder.WebRouter.Helper

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  @snooze_time_param "snooze_time"
  @default_snooze_time Timex.Duration.from_hours(1)
                       |> Timex.Duration.to_milliseconds(truncate: true)
  @max_snooze_time Timex.Duration.from_hours(3) |> Timex.Duration.to_milliseconds(truncate: true)

  delete "/:timer_id" do
    Helper.Auth.authorize_request(conn, timer_id)

    with :ok <- dismiss_timer(timer_id),
         :ok <- record_taken(timer_id) do
      send_resp(conn, 204, "")
    else
      {:error, {:dismiss, :not_timing}} ->
        send_resp(conn, 204, "")

      {:error, {:dismiss, _reason}} ->
        send_resp(conn, 500, %{error: "Failed to dismiss timer"} |> Poison.encode!())

      {:error, {:recording, _reason}} ->
        send_resp(
          conn,
          500,
          %{error: "Failed to record medication as taken, but timer was dismissed."}
          |> Poison.encode!()
        )
    end
  end

  post "/:timer_id/snooze" do
    Helper.Auth.authorize_request(conn, timer_id)

    conn = Plug.Conn.fetch_query_params(conn)

    with {:ok, params} <- parse_snooze_query_params(conn.query_params),
         snooze_ms = Map.get(params, @snooze_time_param),
         :ok <- ReminderSender.snooze(timer_id, snooze_ms) do
      minutes_until = fn ->
        Timex.Duration.from_milliseconds(snooze_ms)
        |> Timex.Duration.to_minutes()
        |> (&:io_lib.format("~.2f", [&1])).()
      end

      Logger.info("Cleared snoozed timer id #{timer_id} for #{minutes_until.()}")
      send_resp(conn, 204, "")
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
    send_resp(conn, 404, "")
  end

  @spec dismiss_timer(String.t()) :: :ok | {:error, {:dismiss, any()}}
  defp dismiss_timer(timer_id) do
    case ReminderSender.dismiss(timer_id) do
      :ok ->
        Logger.info("Cleared timer id #{timer_id}")
        :ok

      {:error, :not_timing} ->
        Logger.debug("Attempted to dismiss timer id #{timer_id} but no timers are running")
        {:error, {:dismiss, :not_timing}}

      {:error, reason} ->
        Logger.error("Failed to dismiss timer with id #{timer_id}: #{inspect(reason)}")
        {:error, {:dismiss, reason}}
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
        Logger.warn("Medication marked as taken for #{timer_id} already today.")

        # I don't think we need to fail this endpoint necessarily, but we should definitely log about it.
        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to record medication as taken timer with id #{timer_id}: #{inspect(reason)}"
        )

        {:error, {:recording, reason}}
    end
  end

  @spec parse_snooze_query_params(%{String.t() => String.t()}) ::
          {:ok, %{String.t() => String.t()}}
          | {:error, {atom, String.t(), {String.t(), String.t()}}}
  defp parse_snooze_query_params(params = %{}) do
    with {:ok, value} <- Util.QueryParam.get_value(params, @snooze_time_param),
         {:ok, snooze_time} <- parse_snooze_time_param(value) do
      parsed_params = Map.put(params, @snooze_time_param, snooze_time)
      {:ok, parsed_params}
    else
      {:error, :not_scalar} ->
        {:error,
         {:invalid_param, "must be a string",
          {@snooze_time_param, Map.get(params, @snooze_time_param)}}}

      err = {:error, _reason} ->
        err
    end
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
end
