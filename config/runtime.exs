import Config

config :pillminder,
  timers: [
    [
      id: "my-pillminder",
      # seconds
      reminder_spacing: 5,
      reminder_start_time: ~T[08:00:00],
      ntfy_topic: "REPLACE_ME"
    ]
  ]
