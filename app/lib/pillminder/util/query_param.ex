defmodule Pillminder.Util.QueryParam do
  @doc """
  Get a single value for the given query parameter. This ensures that the value is specifically a binary type,
  and not a nested list or map, which Plug will allow when parsing.
  """
  @spec get_value(Plug.Conn.query_params(), String.t()) ::
          {:ok, binary() | nil} | {:error, :not_scalar}
  def get_value(params, key) do
    case Map.get(params, key) do
      nil -> {:ok, nil}
      value when is_binary(value) -> {:ok, value}
      _value -> {:error, :not_scalar}
    end
  end
end
