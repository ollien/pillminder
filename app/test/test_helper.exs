# Start tzdata, as Timex needs it. test.exs disables network calls for this.
{:ok, _} = Application.ensure_all_started(:tzdata)

capture_log = System.get_env("SHOW_LOGS") == nil
ExUnit.start(exclude: [:skip], capture_log: capture_log)
