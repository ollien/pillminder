defmodule Pillminder.Notifications do
  @moduledoc """
  Facilitates sending various notification types for different pillminders
  """

  require Logger

  alias Pillminder.Auth
  alias Pillminder.Config
  alias Pillminder.Notifications.Ntfy

  @spec send_reminder_notification(String.t()) :: :ok | {:error, :no_such_timer | any()}
  def send_reminder_notification(timer_id) do
    with {:ok, timer} <- timer_must_exist(timer_id),
         {:ok, token} <- make_notification_token(timer_id) do
      body = reminder_notification_body(timer, token)
      send_ntfy_notification(timer, body)
    end
  end

  @spec send_access_code_notification(String.t(), String.t()) ::
          :ok | {:error, :no_such_timer | any()}
  def send_access_code_notification(timer_id, access_code) do
    case timer_must_exist(timer_id) do
      {:ok, timer} ->
        body = access_code_notification_body(access_code)
        send_ntfy_notification(timer, body)

      err = {:error, _reason} ->
        err
    end
  end

  @spec timer_must_exist(String.t()) :: {:ok, Config.Timer.t()} | {:error, :no_such_timer}
  defp timer_must_exist(timer_id) do
    case Pillminder.lookup_timer(timer_id) do
      nil ->
        {:error, :no_such_timer}

      timer_id ->
        {:ok, timer_id}
    end
  end

  @spec make_notification_token(String.t()) :: {:ok, String.t()} | {:error, {:make_token, any()}}
  defp make_notification_token(timer_id) do
    # TODO: This does mean that the timer will expire on existing notifications, but this is fine for a lot of cases.
    case Auth.make_token(timer_id) do
      {:ok, token} -> {:ok, token}
      {:error, reason} -> {:error, {:make_token, reason}}
    end
  end

  @spec send_ntfy_notification(Config.Timer.t(), %{atom() => any()}) ::
          :ok | {:error, {:ntfy_error, any()}}
  defp send_ntfy_notification(timer, body) do
    case Ntfy.push_notification(timer.ntfy_topic, body, timer.ntfy_api_key) do
      {:ok, resp} ->
        Logger.debug("Got response from ntfy: #{inspect(resp)}")
        :ok

      {:error, reason} ->
        {:error, {:ntfy_error, reason}}
    end
  end

  @spec reminder_notification_body(Config.Timer.t(), String.t()) :: %{atom() => any()}
  defp reminder_notification_body(timer, token) do
    token_headers = %{"Authorization" => "Token #{token}"}

    %{
      title: "Time to take your medication!",
      message: "Pillminder: #{timer.id}",
      actions: [
        %{
          action: "http",
          label: "Mark taken",
          clear: true,
          url: URI.merge(Pillminder.get_base_url(), "/api/v1/timer/#{URI.encode(timer.id)}"),
          method: "DELETE",
          headers: token_headers
        },
        %{
          action: "http",
          label: "Snooze 1hr",
          clear: true,
          url:
            URI.merge(Pillminder.get_base_url(), "/api/v1/timer/#{URI.encode(timer.id)}/snooze"),
          method: "POST",
          headers: token_headers
        }
      ]
    }
  end

  @spec access_code_notification_body(String.t()) :: %{atom() => any()}
  defp access_code_notification_body(access_code) do
    %{
      title: "Your Pillminder access code",
      message: access_code
    }
  end
end
