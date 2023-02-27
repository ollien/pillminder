defmodule Pillminder.Release do
  @moduledoc """
    Utilities to run interactively when Pillminder is built for release
  """

  # https://hexdocs.pm/ecto_sql/Ecto.Migrator.html#module-example-running-migrations-in-a-release

  def migrate() do
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.load(:pillminder)
    Application.fetch_env!(:pillminder, :ecto_repos)
  end
end
