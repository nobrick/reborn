defmodule Utils.ParamTest do
  use ExUnit.Case, async: true
  alias Utils.Param
  doctest Utils.Param

  setup do
    resp = %{"fee" => "0.00", "id" => 16, "total" => "0.81"}
    expected_resp = %{"fee" => 0, "id" => 16, "total" => 0.81}
    {:ok, resp: resp, expected_resp: expected_resp}
  end

  describe "format_resp/1" do
    test "returns expected value", %{resp: resp, expected_resp: expected} do
      assert Param.format_resp(resp) == expected
    end
  end
end
