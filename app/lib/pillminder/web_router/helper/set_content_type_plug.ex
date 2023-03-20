defmodule Pillminder.WebRouter.Helper.SetContentTypePlug do
  import Plug.Conn
  use Plug.Builder

  def init(opts = [content_type: _content_type]) do
    opts
  end

  def call(conn, opts) do
    case get_resp_header(conn, "content-type") do
      [] -> put_resp_content_type(conn, opts[:content_type])
      _ -> conn
    end
  end
end
