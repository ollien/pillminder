defmodule Pillminder.WebRouter do
  require Logger
  alias Pillminder.Util.QueryParam
  alias Pillminder.ReminderSender

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  @snooze_time_param "snooze_time"
  @default_snooze_time Timex.Duration.from_hours(1)
                       |> Timex.Duration.to_milliseconds(truncate: true)
  @max_snooze_time Timex.Duration.from_hours(3) |> Timex.Duration.to_milliseconds(truncate: true)

  delete "/timer/:timer_id" do
    case ReminderSender.dismiss(timer_id) do
      :ok ->
        ReminderSender.dismiss(timer_id)
        Logger.info("Cleared timer id #{timer_id}")
        send_resp(conn, 200, "")

      {:error, :not_timing} ->
        Logger.debug("Attempted to dismiss timer id #{timer_id} but no timers are running")
        send_resp(conn, 200, "")

      {:error, err} ->
        Logger.error("Failed to dismiss timer with id #{timer_id}: #{inspect(err)}")
        send_resp(conn, 500, "")
    end
  end

  post "/timer/:timer_id/snooze" do
    conn = Plug.Conn.fetch_query_params(conn)

    with {:ok, params} <- parse_snooze_query_params(conn.query_params),
         :ok <- ReminderSender.snooze(timer_id, Map.get(params, @snooze_time_param)) do
      send_resp(conn, 200, "")
    else
      {:error, {:invalid_param, reason, {param, _}}} ->
        msg = ~s(Invalid value for query parameter "#{param}": #{reason})
        Logger.debug(msg)
        send_resp(conn, 400, %{error: msg} |> Poison.encode!())

      {:error, :no_timer} ->
        msg = ~s(No timer with id "#{timer_id}")
        send_resp(conn, 404, %{error: msg} |> Poison.encode!())
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end

  @spec parse_snooze_query_params(%{String.t() => String.t()}) ::
          {:ok, %{String.t() => String.t()}}
          | {:error, {atom, String.t(), {String.t(), String.t()}}}
  defp parse_snooze_query_params(params = %{}) do
    with {:ok, value} <- QueryParam.get_value(params, @snooze_time_param),
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
end
