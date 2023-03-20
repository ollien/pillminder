defmodule PillminderTest.WebRouter.Helper.SetContentTypePlug do
  alias Pillminder.WebRouter.Helper.SetContentTypePlug

  import Plug.Conn

  use ExUnit.Case
  use Plug.Test
  doctest Pillminder.WebRouter.Helper.SetContentTypePlug

  test "returns given content type if unset" do
    conn = conn(:get, "/hello", %{hello: "world"} |> Poison.encode!())
    processed_conn = SetContentTypePlug.call(conn, content_type: "application/json")

    assert processed_conn |> get_resp_header("content-type") == [
             "application/json; charset=utf-8"
           ]
  end

  test "doesn't change an already set content type" do
    conn = conn(:get, "/hello", ":)") |> put_resp_header("content-type", "text/plain")
    processed_conn = SetContentTypePlug.call(conn, content_type: "application/json")

    assert processed_conn |> get_resp_header("content-type") == [
             "text/plain"
           ]
  end
end
