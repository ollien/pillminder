defmodule Pillminder.WebRouter.Auth do
  require Logger

  use Plug.Router

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)
  plug(:dispatch)

  post "/access-code" do
    with {:ok, pillminder} <- body_value(conn, "pillminder"),
         {:ok, access_code} <- new_access_code(pillminder) do
      send_resp(conn, 200, Poison.encode!(%{access_code: access_code}))
    else
      {:error, {:missing_in_body, _key}} ->
        Logger.debug("No pillminder found in request")
        send_resp(conn, 400, "")

      {:error, {:make_access_code, reason}} ->
        # I would log the pillminder here but it isn't defined at this point...
        Logger.error("Failed to generate access code: #{reason}")
        send_resp(conn, 500, "")
    end
  end

  post "/token" do
    with {:ok, access_code} <- body_value(conn, "access_code"),
         {:ok, access_code_info} <- exchange_access_code(access_code) do
      response_data = %{pillminder: access_code_info.pillminder, token: access_code_info.token}

      send_resp(
        conn,
        200,
        Poison.encode!(response_data)
      )
    else
      {:error, {:missing_in_body, _key}} ->
        Logger.debug("No access code found in request")
        send_resp(conn, 400, "")

      {:error, {:exchange_token, :invalid_access_code}} ->
        send_resp(conn, 400, "")

      {:error, {:exchange_token, reason}} ->
        # I would log the pillminder here but it isn't defined at this point...
        Logger.error("Failed to exchange access code: #{reason}")
        send_resp(conn, 500, "")
    end
  end

  @spec body_value(Plug.Conn.t(), String.t()) ::
          {:ok, String.t()} | {:error, {:missing_in_body, String.t()}}
  defp body_value(conn, key) do
    case Map.get(conn.body_params, key) do
      nil -> {:error, {:missing_in_body, key}}
      pillminder -> {:ok, pillminder}
    end
  end

  @spec new_access_code(String.t()) ::
          {:ok, String.t()} | {:error, {:make_access_code, String.t()}}
  defp new_access_code(pillminder) do
    case Pillminder.Auth.make_access_code(pillminder) do
      {:ok, access_code} -> {:ok, access_code}
      {:error, reason} -> {:error, {:make_access_code, reason}}
    end
  end

  @spec exchange_access_code(String.t()) ::
          {:ok, Pillminder.Auth.access_code_exchange_info()} | {:error, {:exchange_token, any()}}
  defp exchange_access_code(access_code) do
    case Pillminder.Auth.exchange_access_code(access_code) do
      {:ok, info} -> {:ok, info}
      {:error, reason} -> {:error, {:exchange_token, reason}}
    end
  end
end
