defmodule Pillminder.Util.RunInterval do
  @doc """
  Run the given function on the given interval. This is a thin wrapper around :timer.apply_interval/4
  to allow greater flexibility with Elixir. Given timer_refs can be cancelled with RunInterval.cancel
  """
  @spec apply_interval(non_neg_integer, function, list) ::
          {:error, any} | {:ok, :timer.tref()}
  def apply_interval(time, function, args \\ []) do
    :timer.apply_interval(
      time,
      :erlang,
      :apply,
      [function, args]
    )
  end

  @doc """
  Run the given function on the given interval. This is a thin wrapper around :timer.apply_after/4
  to allow greater flexibility with Elixir. Given timer_refs can be cancelled with RunInterval.cancel
  """
  @spec apply_after(non_neg_integer, function, list) :: {:error, any} | {:ok, :timer.tref()}
  def apply_after(time, function, args \\ []) do
    :timer.apply_after(
      time,
      :erlang,
      :apply,
      [function, args]
    )
  end

  @doc """
  Cancel the given timer_ref. This is a thin wrapper around :timer.cancel
  """
  @spec cancel(:timer.tref()) :: :ok | {:error, any}
  def cancel(timer_ref) do
    cancel_res = :timer.cancel(timer_ref)

    case cancel_res do
      {:ok, :cancel} -> :ok
      {:error, err} -> {:error, err}
    end
  end
end
