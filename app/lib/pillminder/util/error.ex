defmodule Pillminder.Util.Error do
  @doc """
  Return the given value in an :ok tuple, or as an error tuple if it is one already.:w

  ## Examples
      iex> Pillminder.Util.Error.ok_or(23)
      {:ok, 23}

      iex> Pillminder.Util.Error.ok_or({:error, :not_found})
      {:error, :not_found}
  """
  @spec ok_or(value | {:error, err}) :: {:ok, value} | {:error, err} when value: any, err: any
  def ok_or(err = {:error, _}) do
    err
  end

  def ok_or(value) do
    {:ok, value}
  end

  @doc """
  The inverse of ok_or

  ## Examples
      iex> Pillminder.Util.Error.or_error({:ok, 23})
      23

      iex> Pillminder.Util.Error.ok_or({:error, :not_found})
      {:error, :not_found}
  """
  @spec or_error({:ok, value} | {:error, err}) :: value | {:error, err} when value: any, err: any
  def or_error({:ok, value}) do
    value
  end

  def or_error(err = {:error, _reason}) do
    err
  end

  @doc """
  The inverse of ok_or

  ## Examples
      iex> Pillminder.Util.Error.all_ok([{:ok, 23}, {:ok, 54}, {:ok, 12}])
      {:ok, [23, 54, 12]}

      iex> Pillminder.Util.Error.all_ok([{:ok, 23}, {:error, :failed}])
      {:error, :failed}
  """
  @spec all_ok([{:ok, value} | {:error, err}]) :: {:ok, [value]} | {:error, err}
        when value: any, err: any
  def all_ok(items) do
    items
    |> Enum.reverse()
    |> Enum.reduce_while([], fn
      {:ok, value}, acc -> {:cont, [value | acc]}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      err = {:error, _reason} -> err
      unpacked -> {:ok, unpacked}
    end
  end
end
