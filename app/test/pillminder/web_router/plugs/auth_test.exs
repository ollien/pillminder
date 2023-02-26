defmodule PillminderTest.WebRouter.Plugs.Auth do
  alias Pillminder.WebRouter.Plugs

  use ExUnit.Case
  use ExUnit.Parameterized
  use Plug.Test
  doctest Pillminder.WebRouter.Plugs.Auth

  @opts Plugs.Auth.init(timer_id_param: "timer_id")

  setup do
    start_supervised!(Pillminder.Auth)
    :ok
  end

  test "raises if the connection does not have the expected route parameter" do
    # No params
    conn = conn(:get, "/a/b")

    assert_raise(RuntimeError, fn ->
      Plugs.Auth.call(conn, @opts)
    end)
  end

  test "sends a 401 if the timer id has no tokens associated with it" do
    conn =
      conn(:get, "/my-pillminder/summary")
      |> Map.put(:params, %{"timer_id" => "my-pillminder"})
      |> Map.put(:path_params, %{"timer_id" => "my-pillminder"})

    responded_conn = Plugs.Auth.call(conn, @opts)

    assert responded_conn.state == :sent
    assert responded_conn.halted
    assert responded_conn.status == 401
  end

  test "allows request if timer id has token" do
    {:ok, token} = Pillminder.Auth.make_token("my-pillminder")

    conn =
      conn(:get, "/my-pillminder/summary")
      |> Map.put(:params, %{"timer_id" => "my-pillminder"})
      |> Map.put(:path_params, %{"timer_id" => "my-pillminder"})
      |> put_req_header("authorization", "Token #{token}")

    resulting_conn = Plugs.Auth.call(conn, @opts)

    # Conn should not be modified
    assert resulting_conn == conn
  end

  test_with_params(
    "bad request is generated for invalid authorization header",
    fn auth_header_format ->
      {:ok, token} = Pillminder.Auth.make_token("my-pillminder")

      # This is a bit hacky, but ExParametrized does not allow us to pass functions,
      # So this is the nest next thing
      auth_header = String.replace(auth_header_format, "%token", token)

      conn =
        conn(:get, "/my-pillminder/summary")
        |> Map.put(:params, %{"timer_id" => "my-pillminder"})
        |> Map.put(:path_params, %{"timer_id" => "my-pillminder"})
        |> put_req_header("authorization", auth_header)

      responded_conn = Plugs.Auth.call(conn, @opts)

      assert responded_conn.state == :sent
      assert responded_conn.halted
      assert responded_conn.status == 400
    end
  ) do
    [
      {"Bearer %token"},
      {"%token"},
      {"Token %token something extra"},
      {""}
    ]
  end
end
