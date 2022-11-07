defmodule Pillminder.WebRouter do
  alias Pillminder.ReminderServer

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  delete "/timer/:timer_id" do
    dismiss_res = ReminderServer.dismiss_reminder(timer_id)

    case dismiss_res do
      :ok -> send_resp(conn, 200, "")
      {:error, :no_timer} -> send_resp(conn, 200, "")
      # TODO: This should perhaps not just return the error to the user, and just log it
      {:error, err} -> send_resp(conn, 500, Poison.encode!(%{error: err}))
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
