defmodule Pillminder.WebRouter.Auth do
  require Logger

  use Plug.Router

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Poison)
  plug(:dispatch)

  post "/access-code" do
    with {:ok, timer_id} <- body_value(conn, "pillminder"),
         :ok <- timer_id_must_exist(timer_id),
         {:ok, access_code} <- new_access_code(timer_id),
         :ok <- send_access_code(timer_id, access_code) do
      Logger.info("Created access code for timer #{timer_id}")
      send_resp(conn, 204, "")
    else
      {:error, {:missing_in_body, _key}} ->
        Logger.debug("No pillminder/timer_id found in request")
        send_resp(conn, 400, Poison.encode!(%{error: "No pillminder/timer_id found in request"}))

      {:error, {:no_such_timer, timer_id}} ->
        Logger.debug("Timer #{timer_id} not found")
        send_resp(conn, 400, Poison.encode!(%{error: "Invalid pillminder"}))

      {:error, {:make_access_code, reason}} ->
        # I would log the pillminder here but it isn't defined at this point...
        Logger.error("Failed to generate access code: #{reason}")
        send_resp(conn, 500, "")

      {:error, {:make_access_code, reason}} ->
        # I would log the pillminder here but it isn't defined at this point...
        Logger.error("Failed to generate access code: #{reason}")
        send_resp(conn, 500, "")

      {:error, {:send_access_code, reason}} ->
        # I would log the pillminder here but it isn't defined at this point...
        Logger.error("Failed to send access code: #{reason}")
        send_resp(conn, 500, "")
    end
  end

  post "/token" do
    with {:ok, access_code} <- body_value(conn, "access_code"),
         {:ok, access_code_info} <- exchange_access_code(access_code) do
      Logger.info("Created token for timer id #{access_code_info.timer_id}")

      response_data = %{pillminder: access_code_info.timer_id, token: access_code_info.token}

      send_resp(
        conn,
        200,
        Poison.encode!(response_data)
      )
    else
      {:error, {:missing_in_body, _key}} ->
        Logger.debug("No access code found in request")
        send_resp(conn, 400, Poison.encode!(%{error: "Access code is required"}))

      {:error, {:exchange_token, :invalid_access_code}} ->
        send_resp(conn, 400, Poison.encode!(%{error: "Invalid access code"}))

      {:error, {:exchange_token, reason}} ->
        # I would log the timer_id here but it isn't defined at this point...
        Logger.error("Failed to exchange access code: #{reason}")
        send_resp(conn, 500, "")
    end
  end

  @spec body_value(Plug.Conn.t(), String.t()) ::
          {:ok, String.t()} | {:error, {:missing_in_body, String.t()}}
  defp body_value(conn, key) do
    case Map.get(conn.body_params, key) do
      nil -> {:error, {:missing_in_body, key}}
      timer_id -> {:ok, timer_id}
    end
  end

  @spec timer_id_must_exist(String.t()) :: :ok | {:error, {:no_such_timer, String.t()}}
  defp timer_id_must_exist(timer_id) do
    case Pillminder.lookup_timer(timer_id) do
      nil -> {:error, {:no_such_timer, timer_id}}
      _ -> :ok
    end
  end

  @spec new_access_code(String.t()) ::
          {:ok, String.t()} | {:error, {:make_access_code, String.t()}}
  defp new_access_code(timer_id) do
    case Pillminder.Auth.make_access_code(timer_id) do
      {:ok, access_code} -> {:ok, access_code}
      {:error, reason} -> {:error, {:make_access_code, reason}}
    end
  end

  @spec send_access_code(String.t(), String.t()) ::
          :ok | {:error, {:send_access_code, {:no_such_timer, String.t()} | any()}}
  defp send_access_code(timer_id, access_code) do
    case Pillminder.Notifications.send_access_code_notification(timer_id, access_code) do
      :ok -> :ok
      {:error, :no_such_timer} -> {:error, {:send_access_code, {:no_such_timer, timer_id}}}
      {:error, reason} -> {:error, {:send_access_code, reason}}
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
