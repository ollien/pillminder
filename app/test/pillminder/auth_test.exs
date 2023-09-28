defmodule PillminderTest.Auth do
  alias Pillminder.Auth

  # Cannot be async, due to several processes being named as __MODULE__
  use ExUnit.Case
  doctest Pillminder.Auth

  describe "token_valid_for_timer? with fixed token" do
    setup do
      start_supervised!({Pillminder.Auth, fixed_tokens: ["1234"]})
      :ok
    end

    test "allows fixed tokens for any timer" do
      assert Auth.token_valid_for_timer?("1234", "sldkfjsdf")
      assert Auth.token_valid_for_timer?("1234", "sowjnert80234fn")
      assert Auth.token_valid_for_timer?("1234", "likdjflsdf")
    end

    test "rejects unknown fixed tokens for any timer" do
      assert not Auth.token_valid_for_timer?("1235", "sldkfjsdf")
      assert not Auth.token_valid_for_timer?("1235", "1l23jklsdf")
      assert not Auth.token_valid_for_timer?("1235", "sldkfjsdsdf")
    end
  end

  describe "make_token" do
    setup do
      start_supervised!(Pillminder.Auth)
      :ok
    end

    test "generating a token gives access to that timer" do
      {:ok, token} = Auth.make_token("test-pillminder")
      assert Auth.token_valid_for_timer?(token, "test-pillminder")
    end

    test "generating a token does not give access to other timer" do
      {:ok, token} = Auth.make_token("test-pillminder")
      assert not Auth.token_valid_for_timer?(token, "some-other-pillminder")
    end

    test "allows access more than once" do
      {:ok, token} = Auth.make_token("test-pillminder")
      assert Auth.token_valid_for_timer?(token, "test-pillminder")
      assert Auth.token_valid_for_timer?(token, "test-pillminder")
    end
  end

  describe "exchange_access_token" do
    setup do
      start_supervised!(Pillminder.Auth)
      :ok
    end

    test "access code can be exchanged for session token on that timer" do
      {:ok, access_code} = Auth.make_access_code("my-pillminder")
      {:ok, %{token: session_token}} = Auth.exchange_access_code(access_code)

      assert Auth.token_valid_for_timer?(session_token, "my-pillminder")
    end

    test "produced session token is not valid for another timer" do
      {:ok, access_code} = Auth.make_access_code("my-pillminder")
      {:ok, %{token: session_token}} = Auth.exchange_access_code(access_code)

      assert not Auth.token_valid_for_timer?(session_token, "some-other-pillminder")
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
