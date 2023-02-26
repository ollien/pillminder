defmodule Pillminder.Stats.Repo do
  use Ecto.Repo,
    otp_app: :pillminder,
    adapter: Ecto.Adapters.SQLite3
end
