defmodule Pillminder.Notifications.Ntfy.HttpClient do
  use HTTPoison.Base
  @base_url "https://ntfy.sh"

  @impl true
  def process_url(resource) do
    @base_url <> resource
  end

  @impl true
  def process_request_body(body) do
    Poison.encode!(body)
  end

  @impl true
  def process_response_body(body) do
    Poison.decode!(body)
  end
end
