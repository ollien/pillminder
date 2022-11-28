import Config

config :pillminder,
  timers: [
    [
      id: "my-pillminder",
      # seconds
      reminder_spacing: 5,
      reminder_start_time: ~T[18:43:00],
      ntfy_topic: "REPLACE_ME"
    ]
  ],
  base_url: "http://127.0.0.1:8000"
