defmodule Huo.MarketTest do
  use ExUnit.Case

  test "get :simple" do
    assert {:ok, _} = Huo.Market.get(:simple)
  end

  test "get :detail" do
    assert {:ok, _} = Huo.Market.get(:detail)
  end

  test "get :kline" do
    assert {:ok, _} = Huo.Market.get(:kline)
  end
end
