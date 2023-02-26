defmodule PillminderTest.Util.QueryParam do
  alias Pillminder.Util.QueryParam

  use ExUnit.Case, async: true
  doctest Pillminder.Util.QueryParam

  test "can get simple query parameter value" do
    assert QueryParam.get_value(%{"foo" => "bar", "baz" => "whizbang"}, "baz") ==
             {:ok, "whizbang"}
  end

  test "test a missing query parameter returns nil" do
    assert QueryParam.get_value(%{"foo" => "bar", "baz" => "whizbang"}, "not there") == {:ok, nil}
  end

  test "a map value returns an error" do
    assert QueryParam.get_value(%{"foo" => %{}}, "foo") == {:error, :not_scalar}
  end

  test "a list value returns an error" do
    assert QueryParam.get_value(%{"foo" => []}, "foo") == {:error, :not_scalar}
  end
end
