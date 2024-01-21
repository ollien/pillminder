defmodule Pillminder.MixProject do
  use Mix.Project

  def project do
    [
      app: :pillminder,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: [
        prod: [
          config_providers: [
            {Config.Reader, "/etc/pillminder/config.exs"}
          ]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Pillminder.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 1.8"},
      {:poison, "~> 5.0"},
      {:plug, "~> 1.13"},
      {:plug_cowboy, "~> 2.6"},
      {:norm, "~> 0.13"},
      {:timex, "~> 3.7"},
      {:gen_retry, "~> 1.4"},
      # TODO: Remove once exconstructor accepts https://github.com/appcues/exconstructor/pull/55
      {:exconstructor,
       git: "https://github.com/JonathanTron/exconstructor",
       ref: "13c2c6ecb6ea291f2b503b17e6e7aca3919501fe",
       override: true},
      {:ecto_sql, "~> 3.0"},
      {:ecto_sqlite3, "~> 0.14.0"},
      {:secure_random, "~> 0.5"},
      {:quantum, "~> 3.0"},
      {:briefly, "~> 0.4.1", only: [:test]},
      {:ex_parameterized, "~> 1.3", only: [:test]},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      test: &run_tests/1,
      "test.with_logs": fn args ->
        System.put_env("SHOW_LOGS", "1")
        run_tests(args)
      end
    ]
  end

  defp run_tests(args) do
    Mix.env(:test)
    Mix.Task.run("test", ["--no-start"] ++ args)
  end
end
