defmodule Huo.OrderTest do
  use ExUnit.Case, async: true
  alias Huo.Order

  test "get_account_info" do
    assert {:ok, %{"available_btc_display" => _,
                   "available_cny_display" => _,
                   "frozen_btc_display"    => _,
                   "frozen_cny_display"    => _,
                   "loan_btc_display"      => _,
                   "loan_cny_display"      => _,
                   "net_asset"             => _,
                   "total"                 => _}} = Order.get_account_info
  end
end
