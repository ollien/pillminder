defmodule Pillminder.Util.Time do
  alias Pillminder.Util

  @doc """
  Get the current  time, or raise an exception if that fails.
  """
  @spec now!(Timex.Types.valid_timezone()) :: DateTime.t()
  def now!(tz \\ :local) do
    case Timex.now(tz) |> Util.Error.ok_or() do
      {:ok, now} -> now
      {:error, reason} -> raise "Could not get current time: #{reason}"
    end
  end

  @doc """
    Get the next time the given time occurs, or the nest best available option if there is ambiguity.

    It is entirely possible, for instance, after daylight savings time for there to be a time that does
    not exactly match the desired time, but it will match as far as the "delta" goes. e.g. 2am on the DST
    "spring forward" day will happen at 3am, which is the same "time"
  """
  @spec get_next_occurrence_of_time(
          now :: DateTime.t(),
          target_time :: Time.t()
        ) :: DateTime.t()
  def get_next_occurrence_of_time(now, target_time) do
    set_time_in_date(now, target_time)
    |> select_time(now)
  end

  @spec set_time_in_date(DateTime.t(), Time.t()) :: DateTime.t()
  defp set_time_in_date(now, target_time) do
    Timex.set(now,
      hour: target_time.hour,
      minute: target_time.minute,
      second: target_time.second,
      microsecond: target_time.microsecond
    )
  end

  @spec select_time(
          candidate :: DateTime.t(),
          now :: DateTime.t()
        ) :: DateTime.t()
  defp select_time(candidate, now) do
    if Timex.after?(now, candidate) do
      # If we've already passed the candidate time, add one day and resolve the ambiguity if needed
      new_candidate = Timex.shift(candidate, days: 1)
      disambiguate_selected_time(new_candidate)
    else
      candidate
    end
  end

  defp disambiguate_selected_time(%Timex.AmbiguousDateTime{
         before: before_candidate,
         after: after_candidate
       }) do
    # If time has jumped and the hour is the same in both cases, this means only the timezone has
    # changed (at least, in our set of operations), so we pick the earlier one
    if before_candidate.hour == after_candidate.hour do
      before_candidate
    else
      after_candidate
    end
  end

  defp disambiguate_selected_time(candidate) do
    # already not ambiguous
    candidate
  end
end
