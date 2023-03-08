defmodule Pillminder.WebRouter.Helper.Response do
  @moduledoc """
    Contains common responses that are used for different routes
  """

  @spec not_found(String.t()) :: String.t()
  def not_found(timer_id) do
    ~s(No timer with id "#{timer_id}")
  end
end
