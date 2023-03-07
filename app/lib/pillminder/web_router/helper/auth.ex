defmodule Pillminder.WebRouter.Helper.Auth do
  @moduledoc """
  Auth is a plug that will authenticate requests with `Pillminder.Auth`. All requests must pass through a
  route that identifies a specific pillminder, and the route parameter which does so must be specified in the opts.

  This must be specified after the `:match` plug.
  """

  require Logger
  import Plug.Conn

  defmodule BadAuthorization do
    defexception message: "Malformed authorization provided",
                 plug_status: 400
  end

  defmodule WrongOrNoAuthorization do
    defexception message: "Invalid authorization provided",
                 headers: %{"www-authenticate" => "Token"},
                 plug_status: 401
  end

  defmodule Forbidden do
    defexception [
      :message,
      # We treat this as a 404 to not leak what timers exist
      plug_status: 404
    ]

    def exception(timer_id: timer_id) do
      %Forbidden{
        message: ~s(No timer with id "#{timer_id}")
      }
    end
  end

  @spec authorize_request(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def authorize_request(conn, timer_id) do
    with {:ok, token} <- token_from_request(conn),
         :ok <- authorize(conn, token, timer_id) do
      Logger.debug("Authorized request to #{request_url(conn)} on timer_id #{timer_id}")

      conn
    else
      {:error, :no_token} ->
        Logger.info("No token provided for request to #{request_url(conn)}, returning 401")
        raise WrongOrNoAuthorization

      {:error, :bad_request} ->
        Logger.info("Invalid token header for request to #{request_url(conn)}, returning 400")
        raise BadAuthorization

      {:error, :forbidden} ->
        Logger.info(
          "Token is not authorized to access #{timer_id} @ #{request_url(conn)}, returning 404"
        )

        raise Forbidden, timer_id: timer_id
    end
  end

  @spec token_from_request(Plug.Conn.t()) ::
          {:ok, String.t()} | {:error, :no_token | :bad_request}
  defp token_from_request(conn) do
    case get_req_header(conn, "authorization") do
      [header] -> token_from_header_value(header)
      [] -> {:error, :no_token}
    end
  end

  @spec token_from_header_value(String.t()) :: {:ok, String.t()} | {:error, :bad_request}
  defp token_from_header_value(header_value) do
    case String.split(header_value, " ") do
      ["Token", token] -> {:ok, token}
      _ -> {:error, :bad_request}
    end
  end

  @spec authorize(Plug.Conn.t(), String.t(), String.t()) :: :ok | {:error, :forbidden}
  defp authorize(conn, token, timer_id) do
    Logger.debug("Authorizing request to #{request_url(conn)} on timer_id #{timer_id}")

    if Pillminder.Auth.token_valid_for_timer?(token, timer_id) do
      :ok
    else
      {:error, :forbidden}
    end
  end
end
