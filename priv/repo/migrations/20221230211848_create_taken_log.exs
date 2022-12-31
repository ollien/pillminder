defmodule Pillminder.Stats.Repo.Migrations.CreateTakenLog do
  use Ecto.Migration

  def change do
    create table(:taken_log) do
      add(:timer, :varchar, null: false)
      add(:taken_at, :utc_datetime, null: false)
      add(:utc_offset, :float, null: false)
    end

    # We only wish to allow something to be taken once per day, and unfortunately using a generated column
    # is the easiest way to do that
    execute(
      "ALTER TABLE taken_log ADD COLUMN taken_on GENERATED ALWAYS AS (date(taken_at, utc_offset || ' hours')) VIRTUAL",
      "ALTER TABLE taken_log DROP COLUMN taken_on"
    )

    create(unique_index(:taken_log, [:timer, :taken_on]))
  end
end
