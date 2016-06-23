defmodule Huo.OrderTest do
  use ExUnit.Case, async: true
  alias Huo.Order

  test "get_account" do
    assert {:ok, %{"available_btc_display" => _,
                   "available_cny_display" => _,
                   "frozen_btc_display"    => _,
                   "frozen_cny_display"    => _,
                   "loan_btc_display"      => _,
                   "loan_cny_display"      => _,
                   "net_asset"             => _,
                   "total"                 => _}} = Order.get_account
  end

  test "get_ords" do
    assert {:ok, list} = Order.get_ords
    assert is_list(list)
  end

  test "get_recent_orders" do
    assert {:ok, list} = Order.get_recent_ords
    assert is_list(list)
  end
end
