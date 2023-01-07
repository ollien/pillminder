defmodule Pillminder.WebRouter do
  require Logger

  use Plug.Router

  plug(Plug.Logger, log: :info)
  plug(:match)
  plug(:dispatch)

  forward("/timer", to: __MODULE__.Timer)
  forward("/stats", to: __MODULE__.Stats)

  match _ do
    send_resp(conn, 404, "")
  end
end
