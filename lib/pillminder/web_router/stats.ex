defmodule Pillminder.WebRouter.Stats do
  require Logger

  alias Pillminder.Stats
  alias Pillminder.Util

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/:timer_id/summary" do
    with {:get_time, {:ok, now}} <- {:get_time, Timex.local() |> Util.Error.ok_or()},
         today = DateTime.to_date(now),
         {:get_streak, {:ok, streak_length}} <-
           {:get_streak, Stats.streak_length(timer_id, today)},
         {:get_last_taken, {:ok, last_taken_at}} <-
           {:get_last_taken, Stats.last_taken_at(timer_id)} do
      last_taken_on =
        case last_taken_at do
          nil -> nil
          datetime -> datetime |> DateTime.to_date() |> Date.to_iso8601()
        end

      send_resp(
        conn,
        200,
        %{
          streak_length: streak_length,
          last_taken_on: last_taken_on
        }
        |> Poison.encode!()
      )
    else
      {:get_time, {:error, reason}} ->
        Logger.error("Failed to get current time: #{inspect(reason)}")
        send_resp(conn, 500, "")

      {:get_streak, {:error, reason}} ->
        Logger.error("Failed to fetch streak length for timer #{timer_id}: #{inspect(reason)}")
        send_resp(conn, 500, "")

      {:get_last_taken, {:error, reason}} ->
        Logger.error("Failed to fetch last taken at time for #{timer_id}: #{inspect(reason)}")
        send_resp(conn, 500, "")
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
