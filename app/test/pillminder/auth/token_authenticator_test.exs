defmodule PillminderTest.Auth.TokenAuthenticator do
  alias Pillminder.Auth.TokenAuthenticator

  use ExUnit.Case, async: true
  use ExUnit.Parameterized
  doctest Pillminder.Auth.TokenAuthenticator

  # Server must be named so we can run more than one in unit tests
  @server_name TokenAuthenticatorTestServer

  test "rejects a token when none have been created" do
    start_supervised!({TokenAuthenticator, server_opts: [name: @server_name]})
    assert TokenAuthenticator.token_data("1234", server_name: @server_name) == :invalid_token
  end

  test "accepts a token if it's been provided in the list of fixed tokens" do
    start_supervised!(
      {TokenAuthenticator, [fixed_tokens: ["1234"], server_opts: [name: @server_name]]}
    )

    assert TokenAuthenticator.token_data("1234", server_name: @server_name) != :invalid_token
  end

  test "rejects a token if it's not provided in the list of fixed tokens" do
    start_supervised!(
      {TokenAuthenticator, [fixed_tokens: ["1235"], server_opts: [name: @server_name]]}
    )

    assert TokenAuthenticator.token_data("1234", server_name: @server_name) == :invalid_token
  end

  test "accepts a token which has been put into the store" do
    start_supervised!({TokenAuthenticator, server_opts: [name: @server_name]})
    :ok = TokenAuthenticator.put_token("1234", "test-pillminder", server_name: @server_name)

    assert TokenAuthenticator.token_data("1234", server_name: @server_name) != :invalid_token
  end

  test "returns data about a valid token" do
    start_supervised!({TokenAuthenticator, server_opts: [name: @server_name]})
    :ok = TokenAuthenticator.put_token("1234", "test-pillminder", server_name: @server_name)

    %{timer_id: "test-pillminder"} =
      TokenAuthenticator.token_data("1234", server_name: @server_name)
  end

  test_with_params("rejects tokens after the expiry time as passed", fn token_type ->
    {:ok, clock_agent} =
      Agent.start_link(fn -> Timex.to_datetime({{2022, 3, 10}, {10, 0, 0}}) end)

    start_supervised!({
      TokenAuthenticator,
      [
        expiry_time: Timex.Duration.from_minutes(5),
        clock_source: fn -> Agent.get(clock_agent, fn time -> time end) end,
        server_opts: [name: @server_name]
      ]
    })

    :ok =
      case token_type do
        :expiry_based ->
          TokenAuthenticator.put_token("1234", "test-pillminder", server_name: @server_name)

        :single_use ->
          TokenAuthenticator.put_single_use_token("1234", "test-pillminder",
            server_name: @server_name
          )
      end

    Agent.update(clock_agent, fn _time -> Timex.to_datetime({{2022, 3, 10}, {11, 0, 0}}) end)

    assert TokenAuthenticator.token_data("1234", server_name: @server_name) == :invalid_token
  end) do
    [{:expiry_based}, {:single_use}]
  end

  test "expiry based tokens can be retrieved multiple times" do
    start_supervised!({TokenAuthenticator, server_opts: [name: @server_name]})
    :ok = TokenAuthenticator.put_token("1234", "test-pillminder", server_name: @server_name)

    assert TokenAuthenticator.token_data("1234", server_name: @server_name) != :invalid_token
    assert TokenAuthenticator.token_data("1234", server_name: @server_name) != :invalid_token
  end

  test "single use tokens are invalidated after use" do
    start_supervised!({TokenAuthenticator, server_opts: [name: @server_name]})

    :ok =
      TokenAuthenticator.put_single_use_token("1234", "test-pillminder",
        server_name: @server_name
      )

    assert TokenAuthenticator.token_data("1234", server_name: @server_name) != :invalid_token
    assert TokenAuthenticator.token_data("1234", server_name: @server_name) == :invalid_token
  end

  # This test can't really assert very much because the public API doesn't provide a way to introspect
  # the existing tokens (and expired tokens are obviously invalid), so this test is really just proving
  # that this code isn't totally borked
  test_with_params("cleanup expired tokens keeps valid tokens", fn %{
                                                                     valid: valid_tokens,
                                                                     expired: expired_tokens
                                                                   } ->
    {:ok, clock_agent} = Agent.start_link(fn -> Timex.to_datetime({{2023, 2, 5}, {10, 0, 0}}) end)

    start_supervised!({
      TokenAuthenticator,
      [
        expiry_time: Timex.Duration.from_minutes(5),
        clock_source: fn -> Agent.get(clock_agent, fn time -> time end) end,
        server_opts: [name: @server_name]
      ]
    })

    expired_tokens
    |> Enum.each(fn token ->
      TokenAuthenticator.put_token(token, "my-pillminder", server_name: @server_name)
    end)

    Agent.update(clock_agent, fn _time -> Timex.to_datetime({{2022, 2, 5}, {11, 0, 0}}) end)

    valid_tokens
    |> Enum.each(fn token ->
      TokenAuthenticator.put_token(token, "my-pillminder", server_name: @server_name)
    end)

    :ok = TokenAuthenticator.clean_expired_tokens(server_name: @server_name)

    valid_tokens
    |> Enum.each(fn token ->
      assert TokenAuthenticator.token_data(token, server_name: @server_name) != :invalid_token
    end)
  end) do
    [
      # These technically cover more than the case asked for but that's fine...
      {%{valid: [], expired: []}},
      {%{valid: ["abc"], expired: ["123"]}},
      {%{valid: [], expired: ["123", "456", "789"]}},
      {%{valid: ["abc", "def"], expired: []}}
    ]
  end
end
