defmodule Huo.MarketTest do
  use ExUnit.Case

  test "get :simple" do
    Huo.Market.get(:simple) |> inspect |> IO.puts
  end
end
