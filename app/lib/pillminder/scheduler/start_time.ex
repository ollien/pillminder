defmodule Pillminder.Scheduler.StartTime do
  alias Pillminder.Util

  @type start_time_func :: (now :: DateTime.t() -> {:ok, DateTime.t()} | {:error, any()})

  @doc """
  next_possible gets the start time as the next possible instance of the given time.
  See `Util.Time.get_next_occurrence_of_time()/2` for more details.
  """
  @spec next_possible(Time.t()) :: start_time_func()
  def next_possible(start_time) do
    fn now ->
      Util.Time.get_next_occurrence_of_time(now, start_time) |> Util.Error.ok_or()
    end
  end

  @doc """
  next_possible_with_fudge gets the start time as the next possible instance of the given time, with some added
  fudge factor.
  """
  @spec next_possible_with_fudge(Time.t(), non_neg_integer()) :: start_time_func()
  def next_possible_with_fudge(start_time, fudge) do
    fn now ->
      offset = Enum.random(0..fudge) |> Timex.Duration.from_seconds()

      with {:ok, next_possible_time} <- next_possible(start_time).(now),
           {:ok, fudged_time} <- Timex.add(next_possible_time, offset) |> Util.Error.ok_or() do
        case fudged_time do
          %DateTime{} -> {:ok, fudged_time}
          # I have no compelling reason to pick anything other than after in this case, especially considering
          # it's random.
          %Timex.AmbiguousDateTime{} -> {:ok, fudged_time.after}
        end
      end
    end
  end
end
