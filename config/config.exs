import Config

config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:sender_id, :application]

import_config("#{config_env()}.exs")
