defmodule Huo.MarketTest do
  use ExUnit.Case, async: true

  test "get/1 :simple" do
    assert {:ok, _} = Huo.Market.get(:simple)
  end

  test "get/1 :detail" do
    assert {:ok, _} = Huo.Market.get(:detail)
  end

  test "get/1 :k1" do
    assert {:ok, _} = Huo.Market.get(:k1)
  end

  test "get/1 :k15" do
    assert {:ok, _} = Huo.Market.get(:k15)
  end
end
