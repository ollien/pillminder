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
end
