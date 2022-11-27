defmodule Pillminder.WebRouter do
  require Logger
  alias Pillminder.ReminderSender

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  delete "/timer/:timer_id" do
    case ReminderSender.dismiss(timer_id) do
      :ok ->
        ReminderSender.dismiss(timer_id)
        Logger.info("Cleared timer id #{timer_id}")
        send_resp(conn, 200, "")

      {:error, :no_timer} ->
        Logger.debug("Attempted to dismiss timer id #{timer_id} but no timers are running")
        send_resp(conn, 200, "")

      {:error, err} ->
        Logger.error("Failed to dismiss timer with id #{timer_id}: #{inspect(err)}")
        send_resp(conn, 500, "")
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
