defmodule Pillminder.Stats do
  require Logger
  require Ecto.Query

  alias Pillminder.Util
  alias Pillminder.Stats.Repo
  alias Pillminder.Stats.TakenLog

  @doc """
    Record medication as taken at the given datetime for the given timer id.

    Returns an error if the taken_at indicates that medication was taken twice in the same day.
  """
  @spec record_taken(String.t(), DateTime.t()) ::
          :ok | {:error, :already_taken_today | any()}
  def record_taken(timer_id, taken_at) do
    entry = %TakenLog{
      timer: timer_id,
      taken_at: in_utc(taken_at) |> DateTime.truncate(:second),
      utc_offset: utc_offset(taken_at)
    }

    entry
    |> TakenLog.changeset()
    |> Repo.insert()
    |> case do
      {:ok, _entry} ->
        :ok

      {:error, err} ->
        {:error, remap_recording_error(err)}
    end
  end

  @doc """
    Get the last time that medication was taken for the given timer id, if any. If it hasn't been taken at all,
    nil is returned.
  """
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

  @doc """
    Get the last time that medication was taken for the given timer id, if any. If it hasn't been taken at all,
    nil is returned.
  """
  @spec taken_dates(String.t(), Date.t(), number()) ::
          {:ok, %{Date.t() => boolean()}} | {:error, any()}
  def taken_dates(timer_id, starting_at, num_days \\ 7) do
    last_n_entries =
      TakenLog
      |> Ecto.Query.where(timer: ^timer_id)
      |> Ecto.Query.order_by(desc: :taken_at)
      # The limit is an overcorrection but that's fine - we just need to have the last num_days entries
      # available to us, even if there are a few extras
      |> Ecto.Query.limit(^num_days)
      |> Repo.all()

    last_n_entries
    |> Enum.map(&logged_date/1)
    |> Util.Error.all_ok()
    |> case do
      {:ok, last_n_taken_dates} ->
        {:ok, build_taken_dates(starting_at, num_days, last_n_taken_dates)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
    Get the number of days in a row that medication has been given for the latest timer.
  """
  @spec streak_length(String.t()) :: {:ok, number()} | {:error, any()}
  def streak_length(timer_id) do
    Repo.transaction(fn ->
      {last_entry_before_gap(timer_id), most_recent_entry(timer_id)}
    end)
    |> case do
      {:error, err} -> {:error, err}
      {:ok, {streak_head, streak_tail}} -> {:ok, length_between_gaps(streak_head, streak_tail)}
    end
  end

  @doc """
    Get the number of days in a row that medication has been given for the latest timer.

    The provided date is used as a cut-off of sorts. If the medication was taken the day prior to the given date,
    the streak is not yet broken (as the user still has a chance to complete their streak for the given date). However,
    if it has been two days, the streak resets to zero.
  """
  @spec streak_length(String.t(), Date.t()) :: {:ok, number()} | {:error, any()}
  def streak_length(timer_id, today) do
    Repo.transaction(fn ->
      with {:last_taken, {:ok, last_taken_at}} when last_taken_at != nil <-
             {:last_taken, last_taken_at(timer_id)},
           {:time_diff, {:ok, days_since}} <-
             {:time_diff, days_between(today, last_taken_at |> DateTime.to_date())} do
        if days_since > 1 do
          0
        else
          streak_length(timer_id) |> Util.Error.or_error()
        end
      else
        {:last_taken, {:ok, nil}} -> 0
        # TODO: maybe we wish to provide some detail on what part failed
        {_stage, err = {:error, _reason}} -> err
      end
    end)
  end

  @spec remap_recording_error(t) :: :already_taken_today | t when t: any()
  defp remap_recording_error(err) do
    violated_constraints =
      Ecto.Changeset.traverse_errors(
        err,
        fn
          _changeset, :timer, {_msg, opts} ->
            case opts[:constraint] do
              :unique -> :already_taken_today
              _ -> opts
            end

          _changeset, _field, {_msg, opts} ->
            opts
        end
      )
      |> Enum.into([])

    case violated_constraints do
      [timer: [:already_taken_today]] -> :already_taken_today
      # If we don't know how to handle the error directly, we can bubble it up to the caller
      _ -> err
    end
  end

  @spec days_between(Date.t(), Date.t()) :: {:ok, number()} | {:error, any()}
  defp days_between(end_date, start_date) do
    Timex.diff(end_date, start_date, :days)
    |> Util.Error.ok_or()
  end

  @spec length_between_gaps(DateTime.t() | nil, DateTime.t() | nil) :: number()
  defp length_between_gaps(_streak_head = nil, _streak_tail = nil) do
    0
  end

  defp length_between_gaps(_streak_head, _streak_tail = nil) do
    1
  end

  defp length_between_gaps(streak_head, streak_tail) do
    Timex.diff(streak_tail, streak_head, :days) + 1
  end

  @spec most_recent_entry(String.t()) :: DateTime.t() | nil
  defp most_recent_entry(timer_id) do
    TakenLog
    |> Ecto.Query.select([:taken_at])
    |> Ecto.Query.where(timer: ^timer_id)
    |> Ecto.Query.order_by(desc: :taken_at)
    |> Ecto.Query.limit(1)
    |> Repo.one()
    |> case do
      nil -> nil
      %{taken_at: taken_at} -> taken_at
    end
  end

  @spec last_entry_before_gap(String.t()) :: DateTime.t() | nil
  defp last_entry_before_gap(timer_id) do
    lag_query =
      TakenLog
      |> Ecto.Query.windows(last_taken_window: [order_by: [desc: :taken_at]])
      |> Ecto.Query.select(
        [entry],
        %{
          taken_at: entry.taken_at,
          last_taken_at: lag(entry.taken_at, -1) |> over(:last_taken_window)
        }
      )
      |> Ecto.Query.where(timer: ^timer_id)
      |> Ecto.Query.subquery()

    gap_query =
      lag_query
      |> Ecto.Query.select(
        [entry],
        %{
          taken_at: entry.taken_at,
          last_taken_at: entry.last_taken_at,
          gap:
            fragment("CAST(JULIANDAY(?) AS INTEGER)", entry.taken_at) -
              fragment("CAST(JULIANDAY(?) AS INTEGER)", entry.last_taken_at)
        }
      )
      |> Ecto.Query.order_by(desc: :taken_at)
      |> Ecto.Query.subquery()

    gap_query
    # I don't know why, but if I use [:taken_at] instead of binding it like this, the datetime
    # gets converted to a string for some reason.
    |> Ecto.Query.select([entry], %{taken_at: entry.taken_at})
    # Either it will be the last entry (indicating a nil gap), or there will be a space between two days
    |> Ecto.Query.where([entry], is_nil(entry.gap) or entry.gap > 1)
    |> Ecto.Query.limit(1)
    |> Repo.one()
    |> case do
      nil -> nil
      %{taken_at: taken_at} -> taken_at
    end
  end

  @spec in_utc(DateTime.t()) :: DateTime.t()
  defp in_utc(datetime) do
    utc_tz = Timex.Timezone.get("Etc/UTC", datetime)

    Timex.Timezone.convert(datetime, utc_tz)
    |> disambiguate_datetime()
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

  @spec reattach_timezone(DateTime.t(), float()) ::
          {:ok, DateTime.t()} | {:error, {:reattach_timezone, any()}}
  defp reattach_timezone(taken_at, offset) do
    # Timex allows us to express fractional timezone offsets as integers multiplied by 100,
    # we can handle our floating point offsets by rounding after a * 100 multiplication
    integer_offset = round(offset * 100)

    with {:find_tz, {:ok, tz_name}} <-
           {:find_tz, Timex.Timezone.name_of(integer_offset) |> Util.Error.ok_or()},
         {:get_tz, {:ok, tz}} <-
           {:get_tz, Timex.Timezone.get(tz_name) |> Util.Error.ok_or()},
         {:conversion, {:ok, converted}} <-
           {:conversion, Timex.Timezone.convert(taken_at, tz) |> Util.Error.ok_or()} do
      {:ok, disambiguate_datetime(converted)}
    else
      {:find_tz, {:error, :time_zone_not_found}} ->
        Logger.warning(
          "Failed to load time #{inspect(taken_at)} with offset #{offset}: offset produced no timezone. Representing as UTC"
        )

        {:ok, taken_at}

      {stage, {:error, err}} ->
        {:error, {:reattach_timezone, {stage, err}}}
    end
  end

  @spec disambiguate_datetime(DateTime.t() | Timex.AmbiguousDateTime.t()) :: DateTime.t()
  defp disambiguate_datetime(datetime = %DateTime{}) do
    datetime
  end

  # The Timex docs say that unless we have a good reason, we should use "after". In the cases in this module,
  # there is no such reason
  defp disambiguate_datetime(%Timex.AmbiguousDateTime{after: after_datetime}) do
    after_datetime
  end

  @spec logged_date(TakenLog.t()) ::
          {:ok, Date.t()} | {:error, {:date_extraction_failed, {DateTime.t(), number()}, any()}}
  defp logged_date(%{taken_at: utc_taken_at, utc_offset: offset}) do
    case reattach_timezone(utc_taken_at, offset) do
      {:ok, corrected_datetime} ->
        {:ok, DateTime.to_date(corrected_datetime)}

      {:error, reason} ->
        {:error, {:date_extraction_failed, {utc_taken_at, offset}}, reason}
    end
  end

  @spec build_taken_dates(Date.t(), number(), [Date.t()]) :: %{Date.t() => boolean()}
  defp build_taken_dates(start_date, num_days_to_log, taken_dates) do
    0..(num_days_to_log - 1)
    |> Enum.reduce(%{}, fn offset, acc ->
      date =
        start_date
        |> Timex.subtract(Timex.Duration.from_days(offset))

      have_value = Enum.member?(taken_dates, date)
      Map.put(acc, date, have_value)
    end)
  end
end
