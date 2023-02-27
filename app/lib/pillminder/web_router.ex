defmodule Pillminder.WebRouter do
  require Logger

  use Plug.Router
  use Plug.ErrorHandler

  plug(Plug.Logger, log: :info)

  if Mix.env() == :dev do
    plug(Plug.Static,
      at: "/app",
      # Technically this should be part of the OTP release, but this is a development server so I don't
      # _really_ care.
      from: "./web-client/dist/"
    )
  end

  @impl Plug.ErrorHandler
  def handle_errors(conn, _error) do
    # We must do this so we don't send back the default "Something went wrong" string back to the client whenever
    # there is an error, and also ensure we always return some kind of valid JSON when the status code is somewhat
    # meaningful (e.g. an empty 400 is annoying because sometimes we may want to return actual JSON there). Some
    # internal Plug exceptions require use Plug.ErrorHandler in order to get proper status code returned.

    body =
      if conn.status == 500 do
        # Internal errors are fine to not have a response, I think...
        ""
      else
        "{}"
      end

    send_resp(conn, conn.status, body)
  end

  plug(:match)
  plug(:dispatch)

  forward("/api/v1/auth", to: __MODULE__.Auth)
  forward("/api/v1/timer", to: __MODULE__.Timer)
  forward("/api/v1/stats", to: __MODULE__.Stats)

  match _ do
    send_resp(conn, 404, "")
  end
end