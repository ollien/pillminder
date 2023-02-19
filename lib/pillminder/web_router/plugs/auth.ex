defmodule Pillminder.WebRouter.Plugs.Auth do
  @moduledoc """
  Auth is a plug that will authenticate requests with `Pillminder.Auth`. All requests must pass through a
  route that identifies a specific pillminder, and the route parameter which does so must be specified in the opts.

  This must be specified after the `:match` plug.
  """

  require Logger
  import Plug.Conn

  defmodule PlugOpts do
    @enforce_keys :timer_id_param
    defstruct [:timer_id_param]

    @type t() :: %__MODULE__{timer_id_param: String.t()}
  end

  def init(opts) do
    %PlugOpts{
      timer_id_param: Keyword.get(opts, :timer_id_param, "timer_id")
    }
  end

  def call(conn, opts) do
    timer_id = timer_id_from_request(conn, opts)

    case token_from_request(conn) do
      {:error, :no_token} ->
        Logger.info("No token provided for request to #{request_url(conn)}, returning 401")
        halt_with_status(conn, 401)

      {:error, :bad_request} ->
        Logger.info("Invalid token header for request to #{request_url(conn)}, returning 400")
        halt_with_status(conn, 400)

      {:ok, token} ->
        Logger.debug("Authorizing request to #{request_url(conn)} on pillminder #{timer_id}")

        authorized_conn = authorize(conn, token, timer_id)
        Logger.debug("Authorized request to #{request_url(conn)} on pillminder #{timer_id}")

        authorized_conn
    end
  end

  @spec halt_with_status(Plug.Conn.t(), number()) :: Plug.Conn.t()
  defp halt_with_status(conn, status) do
    conn
    |> send_resp(status, "{}")
    |> halt
  end

  @spec timer_id_from_request(Plug.Conn.t(), PlugOpts.t()) :: String.t()
  defp timer_id_from_request(conn, opts) do
    case Map.get(conn.params, opts.timer_id_param) do
      nil ->
        raise "timer id param '#{opts.timer_id_param}' is not present in connection parameters. This is likely a programming error."

      timer_id ->
        timer_id
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

  @spec authorize(Plug.Conn.t(), String.t(), String.t()) :: Plug.Conn.t()
  defp authorize(conn, token, timer_id) do
    if Pillminder.Auth.token_valid_for_pillminder?(token, timer_id) do
      conn
    else
      halt_with_status(conn, 401)
    end
  end
end
