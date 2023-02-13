defmodule PillminderTest.Auth.TokenAuthenticator do
  alias Pillminder.Auth.TokenAuthenticator

  use ExUnit.Case, async: true
  doctest Pillminder.Auth.TokenAuthenticator

  # Server must be named so we can run more than one in unit tests
  @server_name TokenAuthenticatorTestServer

  setup do
    # Start tzdata, as Timex needs it. test.exs disables network calls for this.
    {:ok, _} = Application.ensure_all_started(:tzdata)
    :ok
  end

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

    %{pillminder: "test-pillminder"} =
      TokenAuthenticator.token_data("1234", server_name: @server_name)
  end

  test "rejects tokens after the expiry time as passed" do
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

    :ok = TokenAuthenticator.put_token("1234", "test-pillminder", server_name: @server_name)

    Agent.update(clock_agent, fn _time -> Timex.to_datetime({{2022, 3, 10}, {11, 0, 0}}) end)

    assert TokenAuthenticator.token_data("1234", server_name: @server_name) == :invalid_token
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
      TokenAuthenticator.put_single_use_token("1234", "test-pillminder", server_name: @server_name)

    assert TokenAuthenticator.token_data("1234", server_name: @server_name) != :invalid_token
    assert TokenAuthenticator.token_data("1234", server_name: @server_name) == :invalid_token
  end
end
