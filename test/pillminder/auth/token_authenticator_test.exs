defmodule PillminderTest.Auth.TokenAuthenticator do
  alias Pillminder.Auth.TokenAuthenticator

  use ExUnit.Case, async: true
  doctest Pillminder.Auth.TokenAuthenticator

  setup do
    # Start tzdata, as Timex needs it. test.exs disables network calls for this.
    {:ok, _} = Application.ensure_all_started(:tzdata)
    :ok
  end

  test "rejects a token when none have been created" do
    start_supervised!(TokenAuthenticator)
    assert TokenAuthenticator.token_data("1234") == :invalid_token
  end

  test "accepts a token if it's been provided in the list of fixed tokens" do
    start_supervised!({TokenAuthenticator, [fixed_tokens: ["1234"]]})
    assert TokenAuthenticator.token_data("1234") != :invalid_token
  end

  test "rejects a token if it's not provided in the list of fixed tokens" do
    start_supervised!({TokenAuthenticator, [fixed_tokens: ["1235"]]})
    assert TokenAuthenticator.token_data("1234") == :invalid_token
  end

  test "accepts a token which has been put into the store" do
    start_supervised!(TokenAuthenticator)
    :ok = TokenAuthenticator.put_token("1234", "test-pillminder")

    assert TokenAuthenticator.token_data("1234") != :invalid_token
  end

  test "returns data about a valid token" do
    start_supervised!(TokenAuthenticator)
    :ok = TokenAuthenticator.put_token("1234", "test-pillminder")

    %{pillminder: "test-pillminder"} = TokenAuthenticator.token_data("1234")
  end

  test "rejects tokens after the expiry time as passed" do
    {:ok, clock_agent} =
      Agent.start_link(fn -> Timex.to_datetime({{2022, 3, 10}, {10, 0, 0}}) end)

    start_supervised!({
      TokenAuthenticator,
      [
        expiry_time: Timex.Duration.from_minutes(5),
        clock_source: fn -> Agent.get(clock_agent, fn time -> time end) end
      ]
    })

    :ok = TokenAuthenticator.put_token("1234", "test-pillminder")

    Agent.update(clock_agent, fn _time -> Timex.to_datetime({{2022, 3, 10}, {11, 0, 0}}) end)

    assert TokenAuthenticator.token_data("1234") == :invalid_token
  end

  test "expiry based tokens can be retrieved multiple times" do
    start_supervised!(TokenAuthenticator)
    :ok = TokenAuthenticator.put_token("1234", "test-pillminder")

    assert TokenAuthenticator.token_data("1234") != :invalid_token
    assert TokenAuthenticator.token_data("1234") != :invalid_token
  end

  test "single use tokens are invalidated after use" do
    start_supervised!(TokenAuthenticator)
    :ok = TokenAuthenticator.put_single_use_token("1234", "test-pillminder")

    assert TokenAuthenticator.token_data("1234") != :invalid_token
    assert TokenAuthenticator.token_data("1234") == :invalid_token
  end
end
