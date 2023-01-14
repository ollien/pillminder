defmodule Pillminder.WebRouter do
  require Logger

  use Plug.Router

  plug(Plug.Logger, log: :info)

  if Mix.env() == :dev do
    plug(Plug.Static,
      at: "/app",
      # Technically this should be part of the OTP release, but this is a development server so I don't
      # _really_ care.
      from: "./web-client/dist/"
    )
  end

  plug(:match)
  plug(:dispatch)

  forward("/timer", to: __MODULE__.Timer)
  forward("/stats", to: __MODULE__.Stats)

  match _ do
    send_resp(conn, 404, "")
  end
end
