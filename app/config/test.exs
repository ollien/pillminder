import Config

config :tzdata,
  data_dir: "./test/testdata/tzdata",
  autoupdate: :disabled,
  # Definitely a hack, but tzdata uses this key to determine which http client it uses, so if it
  # actually tries to use hackney, it will get an error
  http_client: nil

config :pillminder, Pillminder.Stats.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :timex,
  local_timezone: "UTC"
