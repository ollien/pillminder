defmodule Pillminder.Util.Time do
  @doc """
    Get the nest time the given time occurs, or the nest best available option if there is ambiguity.

    It is entirely possible, for instance, after daylight savings time for there to be a time that does
    not exactly match the desired time, but it will match as far as the "delta" goes. e.g. 2am on the DST
    "spring forward" day will happen at 3am, which is the same "time"
  """
  @spec get_next_occurrence_of_time(
          now :: DateTime.t(),
          target_time :: Time.t()
        ) :: DateTime.t() | {:error, any}
  def get_next_occurrence_of_time(now, target_time) do
    case set_time_in_date(now, target_time) do
      err = {:error, _} -> err
      candidate -> select_time(now, candidate)
    end
  end

  @spec set_time_in_date(DateTime.t(), Time.t()) :: DateTime.t() | {:error, any}
  defp set_time_in_date(now, target_time) do
    time_as_duration = Timex.Duration.from_time(target_time)

    case Timex.beginning_of_day(now) |> Timex.add(time_as_duration) do
      err = {:error, _} -> err
      # We're just setting the time, and we don't really have a compelling reason to choose the "before"
      # and Timex suggests we pick the "after" anyway
      #
      # (I also don't know that there's an ambiguous case here so I'm going to fall back to the default)
      %Timex.AmbiguousDateTime{after: after_set_time} -> after_set_time
      set_time = %DateTime{} -> set_time
    end
  end

  @spec select_time(
          now :: DateTime.t(),
          candidate :: DateTime.t()
        ) :: DateTime.t()
  defp select_time(now, candidate) do
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
