defmodule Pillminder.WebRouter.Stats do
  require Logger

  alias Pillminder.Stats
  alias Pillminder.Util
  alias Pillminder.WebRouter.Plugs

  use Plug.Router

  plug(:match)
  plug(Plugs.Auth)
  plug(:dispatch)

  get "/:timer_id/summary" do
    with {:ok, today} <- get_date(),
         {:ok, streak_length} <- streak_length(timer_id, today),
         {:ok, last_taken_on} <- last_taken_on(timer_id) do
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
      {:error, _reason} -> send_resp(conn, 500, "")
    end
  end

  get "/:timer_id/history" do
    with {:ok, today} <- get_date(),
         {:ok, taken_log} <- taken_dates(timer_id, today) do
      send_resp(
        conn,
        200,
        %{taken_dates: taken_log} |> Poison.encode!()
      )
    else
      {:error, _reason} ->
        send_resp(conn, 500, "")
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end

  @spec get_date() :: {:ok, Date.t()} | {:error, {:get_time, any()}}
  defp get_date() do
    case Timex.local() |> Util.Error.ok_or() do
      {:ok, now} ->
        {:ok, DateTime.to_date(now)}

      {:error, reason} ->
        Logger.error("Failed to get current date: #{inspect(reason)}")
        {:error, {:get_time, reason}}
    end
  end

  @spec streak_length(String.t(), Date.t()) :: {:ok, number()} | {:error, {:streak_length, any()}}
  defp streak_length(timer_id, today) do
    case Stats.streak_length(timer_id, today) do
      {:ok, length} ->
        {:ok, length}

      {:error, reason} ->
        Logger.error("Failed to fetch streak length for timer #{timer_id}: #{inspect(reason)}")
        {:error, {:streak_length, reason}}
    end
  end

  @spec last_taken_on(String.t()) :: {:ok, Date.t() | nil} | {:error, {:last_taken_at, any()}}
  defp last_taken_on(timer_id) do
    case Stats.last_taken_at(timer_id) do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, last_taken_at} ->
        {:ok, last_taken_at |> DateTime.to_date() |> Date.to_iso8601()}

      {:error, reason} ->
        Logger.error("Failed to fetch last taken at time for #{timer_id}: #{inspect(reason)}")
        {:error, {:last_taken_at, reason}}
    end
  end

  @spec taken_dates(String.t(), Date.t()) ::
          {:ok, [%{String.t() => any()}]} | {:error, {:taken_dates, any()}}
  defp taken_dates(timer_id, today) do
    case Stats.taken_dates(timer_id, today) do
      {:ok, taken_dates} ->
        iso_taken_log =
          taken_dates
          |> Enum.sort_by(fn {date, _taken} -> date end)
          |> Enum.map(fn {date, taken} -> %{date: Date.to_iso8601(date), taken: taken} end)

        {:ok, iso_taken_log}

      {:error, reason} ->
        Logger.error("Failed generate taken log for #{timer_id}: #{inspect(reason)}")
        {:error, {:taken_dates, reason}}
    end
  end
end
