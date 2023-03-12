defmodule Pillminder.Notifications.Ntfy do
  alias Pillminder.Notifications.Ntfy.HttpClient

  @spec push_notification(
          topic :: String.t(),
          notification_options :: %{(String.t() | atom()) => any()},
          api_key :: String.t() | nil
        ) ::
          {:ok, HTTPoison.Response.t()}
          | {:error, {:bad_status, HTTPoison.Response.t()} | HTTPoison.Error.t()}
  def push_notification(topic, notification_options, api_key \\ nil) do
    body = Map.put(notification_options, :topic, topic)

    headers =
      case api_key do
        nil -> []
        api_key -> [{"Authorization", "Bearer #{api_key}"}]
      end

    HttpClient.post("/", body, headers, follow_redirect: true) |> error_for_status()
  end

  @spec error_for_status({:ok, response}) ::
          {:ok, response} | {:error, {:bad_status, response}}
        when response:
               HTTPoison.Response.t() | HTTPoison.AsyncResponse.t() | HTTPoison.MaybeRedirect.t()
  defp error_for_status({:ok, response}) when response.status_code < 400 do
    {:ok, response}
  end

  defp error_for_status({:ok, response}) do
    {:error, {:bad_status, response}}
  end

  @spec error_for_status({:error, HTTPoison.Error.t()}) :: {:error, HTTPoison.Error.t()}
  defp error_for_status(err = {:error, _reason}) do
    err
  end
end
