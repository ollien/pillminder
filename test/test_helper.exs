capture_log = System.get_env("SHOW_LOGS") == nil
ExUnit.start(exclude: [:skip], capture_log: capture_log)
