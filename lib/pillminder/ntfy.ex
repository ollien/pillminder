defmodule Pillminder.Ntfy do
  alias Pillminder.Ntfy.HttpClient

  def push_notification(topic, opts) do
    full_opts = Map.put(opts, :topic, topic)
    HttpClient.post("/", full_opts)
  end
end
