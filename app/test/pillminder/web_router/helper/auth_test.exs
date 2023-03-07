defmodule PillminderTest.WebRouter.Helper.Auth do
  alias Pillminder.WebRouter.Helper

  use ExUnit.Case
  use ExUnit.Parameterized
  use Plug.Test
  doctest Pillminder.WebRouter.Helper.Auth

  defmodule AuthHarness do
    use Plug.Builder
    use Plug.ErrorHandler

    @impl Plug.ErrorHandler
    def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
      send_resp(conn, conn.status, "")
    end

    def call(conn, opts) do
      timer_id = Keyword.get(opts, :timer_id)
      Helper.Auth.authorize_request(conn, timer_id)
    end
  end

  setup do
    start_supervised!(Pillminder.Auth)
    :ok
  end

  test "sends a 401 if the timer id has no tokens associated with it" do
    conn = conn(:get, "/my-pillminder/summary")

    assert_raise Helper.Auth.WrongOrNoAuthorization, fn ->
      AuthHarness.call(conn, timer_id: "my-pillminder")
    end

    assert {401, _headers, _body} = Plug.Test.sent_resp(conn)
  end

  test "sends a 404 if the timer id if token is valid for a different pillminder" do
    {:ok, token} = Pillminder.Auth.make_token("my-pillminder")

    conn =
      conn(:get, "/my-pillminder/summary")
      |> put_req_header("authorization", "Token #{token}")

    assert_raise Helper.Auth.Forbidden, fn ->
      AuthHarness.call(conn, timer_id: "some-other-pillminder")
    end

    assert {404, _headers, _body} = Plug.Test.sent_resp(conn)
  end

  test "allows request if timer id has token" do
    {:ok, token} = Pillminder.Auth.make_token("my-pillminder")

    conn =
      conn(:get, "/my-pillminder/summary")
      |> put_req_header("authorization", "Token #{token}")

    resulting_conn = AuthHarness.call(conn, timer_id: "my-pillminder")

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
        |> put_req_header("authorization", auth_header)

      assert_raise Helper.Auth.BadAuthorization, fn ->
        AuthHarness.call(conn, timer_id: "my-pillminder")
      end

      assert {400, _headers, _body} = Plug.Test.sent_resp(conn)
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
