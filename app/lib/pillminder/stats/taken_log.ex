defmodule Pillminder.Stats.TakenLog do
  use Ecto.Schema

  @type t :: %__MODULE__{
          timer: String.t(),
          taken_at: DateTime.t(),
          utc_offset: float()
        }

  schema "taken_log" do
    field(:timer, :string)
    field(:taken_at, :utc_datetime)
    field(:utc_offset, :float)
  end

  def changeset(log, params \\ %{}) do
    log
    |> Ecto.Changeset.cast(params, [:timer, :taken_at, :utc_offset])
    |> Ecto.Changeset.unique_constraint([:timer, :taken_on])
    |> Ecto.Changeset.validate_required([:timer, :taken_at, :utc_offset])
  end
end
