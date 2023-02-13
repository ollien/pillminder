defmodule Pillminder.Auth.TokenAuthenticator do
  @moduledoc """
  TokenAuthenticator generates tokens that can be used to access individual Pillminders.
  """
  alias Pillminder.Util
  use Agent

  @type clock_source :: (() -> DateTime.t())
  @type token_data :: fixed_token_data() | dynamic_token_data()
  @type token_action :: :reject | :accept | :accept_and_delete
  @type fixed_token_data :: %{expires_at: :never, pillminder: :all, token_type: :fixed}
  @type dynamic_token_data :: %{
          expires_at: DateTime.t(),
          pillminder: String.t(),
          token_type: token_type()
        }
  @type token_type :: :single_use | :expiry_based | :fixed
  @type token_authenticator_opts :: [
          fixed_tokens: [String.t()],
          clock_source: clock_source(),
          expiry_time: Timex.Duration.t(),
          server_opts: GenServer.options()
        ]

  defmodule State do
    alias Pillminder.Auth.TokenAuthenticator

    defstruct tokens: %{},
              clock_source: &Util.Time.now!/0,
              expiry_time: Timex.Duration.from_minutes(10)

    @type t() :: %__MODULE__{
            tokens: %{String.t() => TokenAuthenticator.dynamic_token_data()},
            clock_source: TokenAuthenticator.clock_source(),
            expiry_time: Timex.Duration.t()
          }
  end

  @doc """
    Start a TokenAuthenticator linked to the current PID.

    The `opts` keyword list is used to configure custom options, which are as follows

    - fixed_tokens: Tokens that will always be valid to authenticator (such as for machine-to-machine API use)
    - server_opts: Used to provide custom configuration for GEnServer. See `GenServer` for more details on these options.
  """
  @spec start_link(opts :: token_authenticator_opts()) :: {:ok, pid} | {:error, any} | :ignore
  def start_link(opts \\ []) do
    server_opts = Keyword.get(opts, :server_opts, [])
    full_opts = Keyword.put_new(server_opts, :name, __MODULE__)

    Agent.start_link(fn -> make_initial_state(opts) end, full_opts)
  end

  @doc """
  Get metadata about the given token. If this token is invalid, :invalid_token is returned.

  Note: this is not an idempotent function. If this token is single use, this is how its "single-use" will be consumed.
  """
  @spec token_data(String.t()) :: token_data() | :invalid_token
  def token_data(token) do
    Agent.get_and_update(__MODULE__, fn state ->
      lookup_and_consume_token(token, state)
    end)
  end

  @doc """
  Add a token to the cache; it will live as long as expiry_time on the genserver options
  """
  @spec put_token(String.t(), String.t()) :: :ok | {:error, any()}
  def put_token(token, for_pillminder) do
    Agent.get_and_update(__MODULE__, fn state ->
      store_token(token, :expiry_based, for_pillminder, state)
    end)
  end

  @doc """
  Add a token to the cache, but it will only be able to be used once.
  """
  @spec put_single_use_token(String.t(), String.t()) :: :ok | {:error, any()}
  def put_single_use_token(token, for_pillminder) do
    Agent.get_and_update(__MODULE__, fn state ->
      store_token(token, :single_use, for_pillminder, state)
    end)
  end

  @spec make_initial_state(token_authenticator_opts()) :: State.t()
  defp make_initial_state(start_opts) do
    state_opts =
      start_opts
      |> Enum.filter(fn {key, _value} -> key == :clock_source or key == :expiry_time end)

    fixed_tokens =
      Keyword.get(start_opts, :fixed_tokens, [])
      |> Enum.map(fn token -> {token, make_fixed_token_data()} end)
      |> Enum.into(%{})

    state =
      struct(
        %State{tokens: fixed_tokens},
        state_opts
      )

    state
  end

  @spec lookup_and_consume_token(String.t(), State.t()) ::
          {token_data() | :invalid_token, State.t()}
  defp lookup_and_consume_token(token, state) do
    case get_token_lookup_action(token, state.tokens, state.clock_source) do
      :accept ->
        token_data = Map.get(state.tokens, token)
        {token_data, state}

      :accept_and_delete ->
        {token_data, next_tokens} = Map.pop!(state.tokens, token)
        next_state = %State{state | tokens: next_tokens}
        {token_data, next_state}

      :reject ->
        # If the token is invalid, we should just remove it if it exists; no sense in keeping it around
        next_tokens = Map.delete(state.tokens, token)
        next_state = %State{state | tokens: next_tokens}
        {:invalid_token, next_state}
    end
  end

  @spec get_token_lookup_action(String.t(), %{String.t() => token_data()}, clock_source()) ::
          token_action()
  defp get_token_lookup_action(token, known_tokens, clock_source) do
    case Map.get(known_tokens, token) do
      nil ->
        :reject

      %{token_type: :fixed} ->
        :accept

      %{token_type: :single_use} ->
        :accept_and_delete

      token_data = %{token_type: :expiry_based} ->
        get_expiry_based_token_lookup_action(token_data, clock_source)
    end
  end

  @spec get_expiry_based_token_lookup_action(token_data(), clock_source()) :: token_action()
  defp get_expiry_based_token_lookup_action(
         _token_data = %{token_type: :expiry_based, expires_at: expires_at},
         clock_source
       ) do
    now = clock_source.()

    if Timex.before?(now, expires_at) do
      :accept
    else
      :reject
    end
  end

  @spec store_token(String.t(), :expiry_based | :single_use, String.t(), State.t()) ::
          {:ok | {:error, any()}, State.t()}
  defp store_token(token, token_type, for_pillminder, state) do
    build_token_data_fn =
      case token_type do
        :expiry_based ->
          fn ->
            make_expiry_based_token_data(state.clock_source, state.expiry_time, for_pillminder)
          end

        :single_use ->
          fn ->
            {:ok, make_single_use_token_data(for_pillminder)}
          end
      end

    case build_token_data_fn.() do
      {:ok, token_data} ->
        next_tokens = Map.put(state.tokens, token, token_data)
        next_state = %State{state | tokens: next_tokens}

        {:ok, next_state}

      {:error, reason} ->
        {{:error, {:expiry_time_calculation, reason}}, state}
    end
  end

  @spec make_fixed_token_data() :: fixed_token_data()
  defp make_fixed_token_data() do
    %{expires_at: :never, pillminder: :all, token_type: :fixed}
  end

  @spec make_expiry_based_token_data(clock_source(), Timex.Duration.t(), String.t()) ::
          {:ok, token_data()} | {:error, any}
  defp make_expiry_based_token_data(clock_source, expiry_time, for_pillminder) do
    now = clock_source.()

    case Timex.add(now, expiry_time) |> Util.Error.ok_or() do
      {:ok, expiry_time} ->
        data = %{
          expires_at: expiry_time,
          pillminder: for_pillminder,
          token_type: :expiry_based
        }

        {:ok, data}

      {:error, reason} ->
        {:error, {:expiry_time_calculation, reason}}
    end
  end

  @spec make_single_use_token_data(String.t()) :: token_data()
  defp make_single_use_token_data(for_pillminder) do
    %{
      expires_at: :never,
      pillminder: for_pillminder,
      token_type: :single_use
    }
  end
end
