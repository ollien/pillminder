defmodule Pillminder.Auth do
  alias Pillminder.Auth.TokenAuthenticator

  @token_length 64
  @session_token_server_name SessionTokenAuthenticator

  @doc """
  Check if the given token is valid for the given pillminder.

  Note that this is not an idempotent operation; if the token is single use, this will count as its use.
  """
  @spec token_valid_for_pillminder?(String.t(), String.t()) :: boolean()
  def token_valid_for_pillminder?(token, pillminder) do
    case TokenAuthenticator.token_data(token, server_name: SessionTokenAuthenticator) do
      :invalid_token -> false
      %{pillminder: :all} -> true
      %{pillminder: token_pillminder} -> token_pillminder == pillminder
    end
  end

  @doc """
  Make a new expiry-based token. See `TokenAuthenticator.put_token/2` for more details.
  """
  @spec make_token(String.t()) :: {:ok, String.t()} | {:error, any}
  def make_token(pillminder) do
    token = generate_token()

    case TokenAuthenticator.put_token(token, pillminder, server_name: SessionTokenAuthenticator) do
      :ok -> {:ok, token}
      {:error, reason} -> {:error, {:token_store, reason}}
    end
  end

  @doc """
  Make a new single use token. See `TokenAuthenticator.put_single_use_token/2` for more details.
  """
  @spec make_single_use_token(String.t()) :: {:ok, String.t()} | {:error, any}
  def make_single_use_token(pillminder) do
    token = generate_token()

    case TokenAuthenticator.put_single_use_token(token, pillminder,
           server_name: SessionTokenAuthenticator
         ) do
      :ok -> {:ok, token}
      {:error, reason} -> {:error, {:token_store, reason}}
    end
  end

  @spec generate_token() :: String.t()
  defp generate_token() do
    SecureRandom.hex(@token_length)
  end
end
