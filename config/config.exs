import Config

config :logger, :console,
  format: "$date $time [$level] $message $metadata\n",
  metadata: [:sender_id, :timer_id, :application]

import_config("#{config_env()}.exs")
