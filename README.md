# Pillminder

Pillminder is an application designed to remind you to take your daily medication. It
uses [ntfy.sh](https://ntfy.sh/) to push reminders to your phone at
preconfigured times, until you mark it as taken.

## Setup

Pillminder's docker container expects two directories: a data directory, and a
configuration directory.

Pillminder stores persistent data in an SQLite database, and requires one to be
created before you begin. The simplest way to do this is to just create a 0
byte file named `pillminder.db` in your data directory.

Pillminder also requires a configuration to specify your timers
("pillminders"). This should be called `config.exs` and placed in your config
directory. An example configuration follows

```elixir
config :pillminder,
  timers: [
    [
      # The name of your timer/pillminder
      id: "my-pillminder",
      # How often you will be reminded, expressed in seconds
      reminder_spacing: 5 * 60,
      # The time that you will start being reminded, expressed in the timezone in which this application runs.
      reminder_start_time: ~T[09:30:00],
      # The time zone in which timezones should be used. This can be either :local or a standard timezone string
      # (Timex recognizes some other formats, as well)
      reminder_time_zone: "America/New_York",
      # The topic on which ntfy.sh will remind you. This is technically public, so pick something sufficiently random.
      ntfy_topic: "REPLACE_ME"
      # optional, a "fudge time", expressed seconds. If specified, your
      # reminders will start at the specified start time, plus a random number
      # of seconds, with an upper bound of the specified fudge time
      reminder_start_fudge_time: 10 * 60
    ]
  ],
  # The base address that all URLs in notifications will be based on
  base_url: "http://your-hostname"
  # optional, HTTP server settings
  server:
    # The address for the http server to listen on
    listen_addr: "127.0.0.1"
    # The port for the HTTP server to listen on
    port: 8080
```

Lastly, you must configure Docker Compose to point to your directory. You
should create a `docker-compose.override.yml` in the root of this project as
follows.

```yml
services:
  app:
    volumes:
      - /path/to/your/data/directory:/var/lib/pillminder
      - /path/to/your/config/directory:/etc/pillminder
  web:
    ports:
      - "8080:80"
```

You can start the application with `docker compose up` (if a rebuild is required, run `docker compose build`)

## Development

This application consists of two parts:

- A backend Elixir server to send the reminders, perform statistics tracking,
  and provide a REST API (located in the `app` directory).
- A small React frontend (located in the `web-client` directory). This builds
  to static HTML/JS files, which can be distributed with any webserver.
