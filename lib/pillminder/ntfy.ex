defmodule Pillminder.Ntfy do
  alias Pillminder.Ntfy.HttpClient

  @spec push_notification(topic :: String.t(), ntfy_options :: %{(String.t() | atom()) => any()}) ::
          {:ok, HTTPoison.Response.t()}
          | {:error, {:bad_status, HTTPoison.Response.t()} | HTTPoison.Error.t()}
  def(push_notification(topic, ntfy_options)) do
    body = Map.put(ntfy_options, :topic, topic)
    HttpClient.post("/", body, [], follow_redirect: true) |> error_for_status()
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
