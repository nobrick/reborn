defmodule Caravan.Wheel.Modes.SimpleTest do
  use ExUnit.Case
  import Caravan.Wheel.Modes.Simple, only: [handle_fetch: 1, handle_pull: 1]
  alias Ecto.Adapters.SQL.Sandbox
  alias Dirk.{Ticker, Repo}

  setup do
    :ok = Sandbox.checkout(Repo)
    body = %{"ticker" => %{"buy" => 3880.38, "high" => 3917.24,
                           "last" => 3880.38, "low" => 3874.49,
                           "open" => 3874.65, "sell" => 3880.86,
                           "symbol" => "btccny", "vol" => 201543.4089},
             "time" => "1471777561"}
    ticker = %{bi: 3880.38, hi: 3917.24, la: 3880.38, lo: 3874.49,
                            of: 3880.86, op: 3874.65, vo: 201543.4089,
                            }
    time = {{2016, 8, 21}, {11, 6, 1}}
    {:ok, body: body, expected_ticker: ticker, expected_time: time}
  end

  describe "handle_fetch/1" do
    test "returns a ticker", %{body: body, expected_ticker: ticker,
                               expected_time: time} do
      {:ok, ret} = handle_fetch(body)
      assert %Ticker{} = ret
      assert ^ticker = Map.take(ret, Map.keys(ticker))
      assert %{time: ^time} = ret
    end
  end

  describe "handle_pull/1" do
    test "returns the persisted ticker", %{body: body,
                                           expected_ticker: expected_ticker,
                                           expected_time: expected_time} do
      {:ok, ret} = handle_pull(body)
      assert %Ticker{} = ret
      assert ^expected_ticker = Map.take(ret, Map.keys(expected_ticker))

      %{id: id, time: actual_time} = ret
      {:ok, expected_time} = Ecto.DateTime.cast(expected_time)
      assert :eq = Ecto.DateTime.compare(actual_time, expected_time)
      assert is_integer(id)
    end
  end
end
