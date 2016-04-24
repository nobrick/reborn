defmodule Huo.MarketTest do
  use ExUnit.Case, async: true

  test "get/1 :simple" do
    assert {:ok, _} = Huo.Market.get(:simple)
  end

  test "get/1 :detail" do
    assert {:ok, _} = Huo.Market.get(:detail)
  end

  test "get/1 :kline" do
    assert {:ok, _} = Huo.Market.get(:kline)
  end
end
