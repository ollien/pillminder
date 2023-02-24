import Config

config :pillminder,
  ecto_repos: [Pillminder.Stats.Repo]

config :pillminder, Pillminder.Stats.Repo, database: "./pillminder.db"

config :pillminder, Pillminder.Auth.Cleaner,
  jobs: [
    {"@hourly", {Pillminder.Auth, :clean_expired_tokens, []}}
  ]

config :logger, :console,
  format: "$date $time [$level] $message $metadata\n",
  metadata: [:sender_id, :timer_id, :application]

import_config("#{config_env()}.exs")
