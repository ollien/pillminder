defmodule Pillminder.Notifications do
  @moduledoc """
  Facilitates sending various notification types for different pillminders
  """

  require Logger

  alias Pillminder.Config
  alias Pillminder.Notifications.Ntfy

  @spec send_reminder_notification(String.t()) :: :ok | {:error, :no_such_timer | any()}
  def send_reminder_notification(timer_id) do
    case get_timer_metadata(timer_id) do
      nil ->
        {:error, :no_such_timer}

      timer ->
        body = reminder_notification_body(timer)
        send_ntfy_notification(timer, body)
    end
  end

  @spec send_access_code_notification(String.t(), String.t()) ::
          :ok | {:error, :no_such_timer | any()}
  def send_access_code_notification(timer_id, access_code) do
    case get_timer_metadata(timer_id) do
      nil ->
        {:error, :no_such_timer}

      timer ->
        body = access_code_notification_body(access_code)
        send_ntfy_notification(timer, body)
    end
  end

  @spec get_timer_metadata(String.t()) :: Config.Timer.t() | nil
  defp get_timer_metadata(timer_id) do
    Config.load_timers_from_env!()
    |> Enum.find(fn timer -> timer.id == timer_id end)
  end

  @spec send_ntfy_notification(Config.Timer.t(), %{atom() => any()}) ::
          :ok | {:error, {:ntfy_error, any()}}
  defp send_ntfy_notification(timer, body) do
    case Ntfy.push_notification(timer.ntfy_topic, body) do
      {:ok, resp} ->
        Logger.debug("Got response from ntfy: #{inspect(resp)}")
        :ok

      {:error, reason} ->
        {:error, {:ntfy_error, reason}}
    end
  end

  @spec reminder_notification_body(Config.Timer.t()) :: %{atom() => any()}
  defp reminder_notification_body(timer) do
    %{
      title: "Time to take your medication!",
      actions: [
        %{
          action: "http",
          label: "Mark taken",
          clear: true,
          url: URI.merge(Pillminder.get_base_url(), "/timer/#{URI.encode(timer.id)}"),
          method: "DELETE"
        },
        %{
          action: "http",
          label: "Snooze 1hr",
          clear: true,
          url: URI.merge(Pillminder.get_base_url(), "/timer/#{URI.encode(timer.id)}/snooze"),
          method: "POST"
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
