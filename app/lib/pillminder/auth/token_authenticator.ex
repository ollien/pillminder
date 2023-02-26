defmodule Pillminder.Auth.TokenAuthenticator do
  @moduledoc """
  TokenAuthenticator generates tokens that can be used to access individual Pillminders.
  """
  alias Pillminder.Util
  use Agent

  @type clock_source :: (() -> DateTime.t())
  @type token_data :: fixed_token_data() | dynamic_token_data()
  @type token_action :: :reject | :accept | :accept_and_delete
  @type fixed_token_data :: %{expires_at: :never, timer_id: :all, token_type: :fixed}
  @type dynamic_token_data :: %{
          expires_at: DateTime.t(),
          timer_id: String.t(),
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
              expiry_time: Timex.Duration.from_minutes(30)

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
  @spec token_data(String.t(), server_name: GenServer.server()) :: token_data() | :invalid_token
  def token_data(token, opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)

    Agent.get_and_update(destination, fn state ->
      lookup_and_consume_token(token, state)
    end)
  end

  @doc """
  Add a token to the cache; it will live as long as expiry_time on the genserver options
  """
  @spec put_token(String.t(), String.t(), server_name: GenServer.server()) ::
          :ok | {:error, any()}
  def put_token(token, for_timer_id, opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)

    Agent.get_and_update(destination, fn state ->
      store_token(token, :expiry_based, for_timer_id, state)
    end)
  end

  def clean_expired_tokens(opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)

    Agent.update(destination, fn state ->
      clean_tokens(state)
    end)
  end

  @doc """
  Add a token to the cache, but it will only be able to be used once.
  """
  @spec put_single_use_token(String.t(), String.t(), server_name: GenServer.server()) ::
          :ok | {:error, any()}
  def put_single_use_token(token, for_timer_id, opts \\ []) do
    destination = Keyword.get(opts, :server_name, __MODULE__)

    Agent.get_and_update(destination, fn state ->
      store_token(token, :single_use, for_timer_id, state)
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
      nil -> :reject
      %{token_type: :fixed} -> :accept
      token_data -> get_dynamic_token_lookup_action(token_data, clock_source)
    end
  end

  @spec get_dynamic_token_lookup_action(token_data(), clock_source()) :: token_action()
  defp get_dynamic_token_lookup_action(
         _token_data = %{token_type: :expiry_based, expires_at: expires_at},
         clock_source
       ) do
    get_token_action_by_expiry(expires_at, clock_source)
  end

  defp get_dynamic_token_lookup_action(
         _token_data = %{token_type: :single_use, expires_at: expires_at},
         clock_source
       ) do
    case get_token_action_by_expiry(expires_at, clock_source) do
      :accept -> :accept_and_delete
      :reject -> :reject
    end
  end

  @spec get_token_action_by_expiry(DateTime.t(), clock_source()) :: token_action()
  defp get_token_action_by_expiry(
         expires_at,
         clock_source
       ) do
    now = clock_source.()

    if expired?(now, expires_at) do
      :reject
    else
      :accept
    end
  end

  @spec expired?(DateTime.t(), DateTime.t() | :never) :: boolean()
  defp expired?(_now, :never) do
    false
  end

  defp expired?(now, expires_at) do
    Timex.after?(now, expires_at)
  end

  @spec store_token(String.t(), :expiry_based | :single_use, String.t(), State.t()) ::
          {:ok | {:error, any()}, State.t()}
  defp store_token(token, token_type, for_timer_id, state) do
    token_data_res =
      make_dynamic_token_data(state.clock_source, state.expiry_time, token_type, for_timer_id)

    case token_data_res do
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
    %{expires_at: :never, timer_id: :all, token_type: :fixed}
  end

  @spec make_dynamic_token_data(
          clock_source(),
          Timex.Duration.t(),
          :expiry_based | :single_use,
          String.t()
        ) ::
          {:ok, token_data()} | {:error, any}
  defp make_dynamic_token_data(clock_source, expiry_time, token_type, for_timer_id) do
    now = clock_source.()

    case expiry_timestamp(now, expiry_time) do
      {:ok, expiry_timestamp} ->
        data = %{
          expires_at: expiry_timestamp,
          timer_id: for_timer_id,
          token_type: token_type
        }

        {:ok, data}

      {:error, reason} ->
        {:error, {:expiry_time_calculation, reason}}
    end
  end

  @spec expiry_timestamp(DateTime.t(), Timex.Duration.t()) ::
          {:ok, DateTime.t()} | {:error, any()}
  defp expiry_timestamp(now, expiry_time) do
    Timex.add(now, expiry_time) |> Util.Error.ok_or()
  end

  @spec clean_tokens(State.t()) :: State.t()
  defp clean_tokens(state) do
    now = state.clock_source.()

    Map.update!(state, :tokens, fn tokens ->
      tokens
      |> Enum.reject(fn {_token, %{expires_at: expires_at}} ->
        IO.puts("#{inspect(now)} #{inspect(expires_at)}")
        expired?(now, expires_at)
      end)
      |> Map.new()
    end)
  end
end
