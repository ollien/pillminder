defmodule Pillminder.Auth do
  @moduledoc """
  Auth handles token management for authenticating requests when accessing pillminders/timers.
  """

  alias Pillminder.Auth.TokenAuthenticator
  use Supervisor

  @access_code_length 6
  @session_token_length 64
  @access_code_server_name __MODULE__.AccessTokenAuthenticator
  @session_token_server_name __MODULE__.SessionTokenAuthenticator

  @type auth_opts :: [fixed_tokens: [String.t()]]
  @type access_code_exchange_info :: %{token: String.t(), timer_id: String.t()}

  @spec start_link(auth_opts()) :: {:ok, pid} | {:error, any} | :ignore
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    fixed_tokens = Keyword.get(opts, :fixed_tokens, [])

    children = [
      Supervisor.child_spec(
        {TokenAuthenticator,
         fixed_tokens: fixed_tokens, server_opts: [name: @session_token_server_name]},
        id: @session_token_server_name
      ),
      Supervisor.child_spec({TokenAuthenticator, server_opts: [name: @access_code_server_name]},
        id: @access_code_server_name
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Check if the given token is valid for the given timer_id.
  """
  @spec token_valid_for_timer?(String.t(), String.t()) :: boolean()
  def token_valid_for_timer?(token, timer_id) do
    case TokenAuthenticator.token_data(token, server_name: @session_token_server_name) do
      :invalid_token -> false
      %{timer_id: :all} -> true
      %{timer_id: token_timer_id} -> token_timer_id == timer_id
    end
  end

  @doc """
  Make a new expiry-based token. See `TokenAuthenticator.put_token/2` for more details.
  """
  @spec make_token(String.t()) :: {:ok, String.t()} | {:error, any()}
  def make_token(timer_id) do
    token = generate_token()

    case TokenAuthenticator.put_token(token, timer_id, server_name: @session_token_server_name) do
      :ok -> {:ok, token}
      {:error, reason} -> {:error, {:token_store, reason}}
    end
  end

  @doc """
  Make a new single use access code, which can be exchanged for a session token using `exchange_access_token/1`
  """
  @spec make_access_code(String.t()) :: {:ok, String.t()} | {:error, any()}
  def make_access_code(timer_id) do
    token = generate_access_code()

    case TokenAuthenticator.put_single_use_token(token, timer_id,
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
          {:ok, access_code_exchange_info()} | {:error, :invalid_access_code | any()}
  def exchange_access_code(access_code) do
    with {:ok, data} <- access_code_data(access_code),
         {:ok, token} <- make_token(data.timer_id) do
      {:ok, %{timer_id: data.timer_id, token: token}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec access_code_data(String.t()) ::
          {:ok, TokenAuthenticator.token_data()} | {:error, :invalid_access_code}
  defp access_code_data(access_code) do
    token_data = TokenAuthenticator.token_data(access_code, server_name: @access_code_server_name)

    case token_data do
      %{timer_id: _timer_id} -> {:ok, token_data}
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
