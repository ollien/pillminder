defmodule PillminderTest.Auth do
  alias Pillminder.Auth
  alias Pillminder.Auth.TokenAuthenticator

  use ExUnit.Case, async: true
  doctest Pillminder.Auth

  @access_code_server_name AccessTokenAuthenticator
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

  describe "exchange_access_token" do
    setup do
      start_supervised!({TokenAuthenticator, server_opts: [name: @access_code_server_name]},
        id: @access_code_server_name
      )

      start_supervised!({TokenAuthenticator, server_opts: [name: @session_token_server_name]},
        id: @session_token_server_name
      )

      :ok
    end

    test "access code can be exchanged for session token on that pillminder" do
      {:ok, access_code} = Auth.make_access_code("my-pillminder")
      {:ok, session_token} = Auth.exchange_access_code(access_code)

      assert Auth.token_valid_for_pillminder?(session_token, "my-pillminder")
    end

    test "produced session token is not valid for another pillminder" do
      {:ok, access_code} = Auth.make_access_code("my-pillminder")
      {:ok, session_token} = Auth.exchange_access_code(access_code)

      assert not Auth.token_valid_for_pillminder?(session_token, "some-other-pillminder")
    end

    test "an invalid access code returns :invalid_access_code" do
      assert Auth.exchange_access_code("123456") == {:error, :invalid_access_code}
    end

    test "an access code can only be exchanged once" do
      {:ok, access_code} = Auth.make_access_code("my-pillminder")
      {:ok, _session_token} = Auth.exchange_access_code(access_code)
      assert Auth.exchange_access_code(access_code) == {:error, :invalid_access_code}
    end
  end
end
