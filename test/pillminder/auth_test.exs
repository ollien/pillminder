defmodule PillminderTest.Auth do
  alias Pillminder.Auth
  alias Pillminder.Auth.TokenAuthenticator

  use ExUnit.Case, async: true
  doctest Pillminder.Auth

  @session_token_server_name SessionTokenAuthenticator

  setup do
    # Start tzdata, as Timex needs it. test.exs disables network calls for this.
    {:ok, _} = Application.ensure_all_started(:tzdata)

    :ok
  end

  describe "token_valid_for_pillminder?" do
    setup do
      start_supervised!({TokenAuthenticator, server_opts: [name: @session_token_server_name]})
      :ok
    end

    test "allows dynamic tokens for their assigned pillminders" do
      :ok =
        TokenAuthenticator.put_single_use_token("1234", "test-pillminder",
          server_name: @session_token_server_name
        )

      assert Auth.token_valid_for_pillminder?("1234", "test-pillminder")
    end

    test "rejects dynamic tokens for their other pillminders" do
      :ok =
        TokenAuthenticator.put_single_use_token("1234", "test-pillminder",
          server_name: @session_token_server_name
        )

      assert not Auth.token_valid_for_pillminder?("1234", "some-other-pillminder")
    end
  end

  describe "token_valid_for_pillminder? with fixed token" do
    setup do
      start_supervised!(
        {TokenAuthenticator,
         fixed_tokens: ["1234"], server_opts: [name: @session_token_server_name]}
      )

      :ok
    end

    test "allows fixed tokens for their any pillminder" do
      assert Auth.token_valid_for_pillminder?("1234", "sldkfjsdf")
      assert Auth.token_valid_for_pillminder?("1234", "sowjnert80234fn")
      assert Auth.token_valid_for_pillminder?("1234", "likdjflsdf")
    end

    test "rejects unknown fixed tokens for any pillminder" do
      assert not Auth.token_valid_for_pillminder?("1235", "sldkfjsdf")
      assert not Auth.token_valid_for_pillminder?("1235", "1l23jklsdf")
      assert not Auth.token_valid_for_pillminder?("1235", "sldkfjsdsdf")
    end
  end

  describe "make_token" do
    setup do
      start_supervised!({TokenAuthenticator, server_opts: [name: @session_token_server_name]})
      :ok
    end

    test "generating a token gives access to that pillminder" do
      {:ok, token} = Auth.make_token("test-pillminder")
      assert Auth.token_valid_for_pillminder?(token, "test-pillminder")
    end

    test "generating a token does not give access to other pillminder" do
      {:ok, token} = Auth.make_token("test-pillminder")
      assert not Auth.token_valid_for_pillminder?(token, "some-other-pillminder")
    end

    test "allows access more than once" do
      {:ok, token} = Auth.make_token("test-pillminder")
      assert Auth.token_valid_for_pillminder?(token, "test-pillminder")
      assert Auth.token_valid_for_pillminder?(token, "test-pillminder")
    end
  end

  describe "make_single_use_token" do
    setup do
      start_supervised!({TokenAuthenticator, server_opts: [name: @session_token_server_name]})
      :ok
    end

    test "generating a token gives access to that pillminder" do
      {:ok, token} = Auth.make_single_use_token("test-pillminder")
      assert Auth.token_valid_for_pillminder?(token, "test-pillminder")
    end

    test "generating a token does not give access to other pillminder" do
      {:ok, token} = Auth.make_single_use_token("test-pillminder")
      assert not Auth.token_valid_for_pillminder?(token, "some-other-pillminder")
    end

    test "a single user token does not allow access more than once" do
      {:ok, token} = Auth.make_single_use_token("test-pillminder")
      assert Auth.token_valid_for_pillminder?(token, "test-pillminder")
      assert not Auth.token_valid_for_pillminder?(token, "test-pillminder")
    end
  end
end
