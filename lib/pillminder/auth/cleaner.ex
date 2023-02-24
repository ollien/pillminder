defmodule Pillminder.Auth.Cleaner do
  @moduledoc """
  A Quantum which is used to run cleanup tasks in the auth server
  """
  use Quantum, otp_app: :pillminder

  # I'd ideally put the cleanup functions here but it's a bit easier (due to module attribute definitions)
  # to do this in Auth
end
