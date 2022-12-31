defmodule Pillminder.Stats do
  require Logger
  require Ecto.Query

  alias Pillminder.Util
  alias Pillminder.Stats.Repo
  alias Pillminder.Stats.TakenLog

  @spec record_taken(String.t(), DateTime.t()) :: :ok | {:error, any()}
  def record_taken(timer_id, taken_at) do
    entry = %TakenLog{
      timer: timer_id,
      taken_at: in_utc(taken_at),
      utc_offset: utc_offset(taken_at)
    }

    entry
    |> TakenLog.changeset()
    |> Repo.insert()
    |> case do
      {:ok, _entry} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  @spec last_taken_at(String.t()) :: {:ok, DateTime.t() | nil} | {:error, any()}
  def last_taken_at(timer_id) do
    last_entry =
      TakenLog
      |> Ecto.Query.where(timer: ^timer_id)
      |> Ecto.Query.order_by(desc: :taken_at)
      |> Ecto.Query.first()
      |> Repo.one()

    case last_entry do
      nil ->
        {:ok, nil}

      %{taken_at: utc_taken_at, utc_offset: offset} ->
        utc_taken_at |> reattach_timezone(offset)
    end
  end

  @spec in_utc(DateTime.t()) :: DateTime.t()
  defp in_utc(datetime) do
    utc_tz = Timex.Timezone.get("Etc/UTC", datetime)

    case Timex.Timezone.convert(datetime, utc_tz) do
      utc_datetime = %DateTime{} -> utc_datetime
      %Timex.AmbiguousDateTime{after: after_datetime} -> after_datetime
    end
  end

  # Get the UTC offset of the given datetime for database persistence
  @spec utc_offset(DateTime.t()) :: float()
  defp utc_offset(datetime) do
    offset_seconds =
      datetime
      |> Timex.TimezoneInfo.from_datetime()
      |> Timex.Timezone.total_offset()

    offset_seconds / 3600
  end

  @spec reattach_timezone(DateTime.t(), float()) :: {:ok, DateTime.t()} | {:error, any()}
  defp reattach_timezone(taken_at, offset) do
    # Timex allows us to express fractional timezone offsets as integers multiplied by 100,
    # we can handle our floating point offsets by rounding after a * 100 multiplication
    integer_offset = round(offset * 100)

    with {:ok, tz_name} <- Timex.Timezone.name_of(integer_offset) |> Util.Error.ok_or(),
         {:ok, tz} <- Timex.Timezone.get(tz_name) |> Util.Error.ok_or() do
      converted = Timex.Timezone.convert(taken_at, tz)
      {:ok, converted}
    else
      {:error, :unknown_timezone} ->
        Logger.warning(
          "Failed to load time #{inspect(taken_at)} with offset #{offset}: offset produced no timezone. Representing as UTC"
        )

        {:ok, taken_at}

      {:error, err} ->
        {:error, err}
    end
  end
end
