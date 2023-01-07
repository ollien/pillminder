defmodule Pillminder.WebRouter.Stats do
  require Logger

  alias Pillminder.Stats

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/:timer_id/streak" do
    case Stats.streak_length(timer_id) do
      {:ok, length} ->
        send_resp(conn, 200, %{streak_length: length} |> Poison.encode!())

      {:error, reason} ->
        Logger.error("Failed to fetch streak length for timer #{timer_id}: #{inspect(reason)}")
        send_resp(conn, 500, "")
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
