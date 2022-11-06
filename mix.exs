defmodule Pillminder.MixProject do
  use Mix.Project

  def project do
    [
      app: :pillminder,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
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
    []
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end
end
