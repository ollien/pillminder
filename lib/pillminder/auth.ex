defmodule Pillminder.Auth do
  alias Pillminder.Auth.TokenAuthenticator

  @access_code_length 6
  @session_token_length 64
  @access_code_server_name AccessTokenAuthenticator
  @session_token_server_name SessionTokenAuthenticator

  @doc """
  Check if the given token is valid for the given pillminder.
  """
  @spec token_valid_for_pillminder?(String.t(), String.t()) :: boolean()
  def token_valid_for_pillminder?(token, pillminder) do
    case TokenAuthenticator.token_data(token, server_name: @session_token_server_name) do
      :invalid_token -> false
      %{pillminder: :all} -> true
      %{pillminder: token_pillminder} -> token_pillminder == pillminder
    end
  end

  @doc """
  Make a new expiry-based token. See `TokenAuthenticator.put_token/2` for more details.
  """
  @spec make_token(String.t()) :: {:ok, String.t()} | {:error, any()}
  def make_token(pillminder) do
    token = generate_token()

    case TokenAuthenticator.put_token(token, pillminder, server_name: @session_token_server_name) do
      :ok -> {:ok, token}
      {:error, reason} -> {:error, {:token_store, reason}}
    end
  end

  @doc """
  Make a new single use access code, which can be exchanged for a session token using `exchange_access_token/1`
  """
  @spec make_access_code(String.t()) :: {:ok, String.t()} | {:error, any()}
  def make_access_code(pillminder) do
    token = generate_access_code()

    case TokenAuthenticator.put_single_use_token(token, pillminder,
           server_name: @access_code_server_name
         ) do
      :ok -> {:ok, token}
      {:error, reason} -> {:error, {:access_code_store, reason}}
    end
  end

  @doc """
  Exchange an access code for a session token. If the access code is invalid, then {:error, :invalid_access_code} is returned.
  """
  @spec exchange_access_code(String.t()) ::
          {:ok, String.t()} | {:error, :invalid_access_code | any()}
  def exchange_access_code(access_code) do
    token_data = TokenAuthenticator.token_data(access_code, server_name: @access_code_server_name)

    case token_data do
      %{pillminder: pillminder} -> make_token(pillminder)
      :invalid_token -> {:error, :invalid_access_code}
    end
  end

  @spec generate_token() :: String.t()
  defp generate_token() do
    SecureRandom.hex(@session_token_length)
  end

  @spec generate_access_code() :: String.t()
  defp generate_access_code() do
    SecureRandom.random_bytes(@access_code_length)
    |> :binary.bin_to_list()
    |> Enum.map(fn byte -> rem(byte, 10) end)
    |> Enum.map(&Integer.to_string/1)
    |> Enum.join()
  end
end
