defmodule Pillminder.RunInterval do
  @doc """
  Run the given function on the given interval. This is a thin wrapper around :timer.apply_interval/4
  to allow greater flexibility with Elixir.
  """
  @spec apply_interval(:timer.time(), function, list) ::
          {:error, any} | {:ok, :timer.tref()}
  def apply_interval(time, function) do
    apply_interval(time, function, [])
  end

  def apply_interval(time, function, args) do
    :timer.apply_interval(
      time,
      :erlang,
      :apply,
      [function, args]
    )
  end
end
