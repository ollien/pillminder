defmodule Pillminder.Config.Server do
  @moduledoc """
  Settings for the HTTP server that serves the API
  """

  import Norm
  defstruct port: 8000, listen_addr: "0.0.0.0"

  @type t() :: %__MODULE__{
          port: number(),
          listen_addr: String.t()
        }

  def s,
    do:
      schema(%__MODULE__{
        port: spec(is_integer() and (&(&1 >= 0 and &1 <= 65535))),
        listen_addr: spec(is_binary())
      })
end
