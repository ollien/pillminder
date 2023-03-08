defmodule Pillminder.WebRouter.Helper.Auth do
  @moduledoc """
  Auth helps authenticate requests with `Pillminder.Auth` for a specific timer. This is useful to ensure
  that routes do not have to constantly re-specify auth logic
  """

  require Logger
  import Plug.Conn

  alias Pillminder.WebRouter.Helper

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
        message: Helper.Response.not_found(timer_id)
      }
    end
  end

  # Dialyzer gets confused about the 'with' statement here.
  # https://dev.to/lasseebert/til-understanding-dialyzer-s-the-pattern-can-never-match-the-type-2mmm
  @dialyzer {:no_match, authorize_request: 2}
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
