defmodule Dirk.TickerTest do
  use ExUnit.Case, async: true
  import Ecto.DateTime, only: [cast!: 1]
  import Utils.Ecto, only: [in_time_range: 3, in_time_range: 4]
  alias Ecto.Adapters.SQL.Sandbox
  alias Dirk.Ticker
  alias Dirk.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
    fixtures = [[{13, 0, 58}, 3000],
                  [{13, 0, 59}, 2998],
                  [{13, 1, 0}, 2998]]
    tickers = List.foldl(fixtures, [], fn [time_part, la], acc ->
      time = {{2016, 4, 20}, time_part}
      params = %{op: 2900.0, la: la, hi: 3100.0, lo: 2800.0, vo: 1600000.0,
                 of: 3000.0, bi: 3000.0, d_la: 0.00001, time: cast!(time)}
      {:ok, ticker} = Repo.insert(Ticker.changeset(:create, %Ticker{}, params))
      List.insert_at(acc, -1, ticker)
    end)
    {:ok, tickers: tickers}
  end

  test "in_time_range/4 returns the expected query",
      %{tickers: [_ticker_0, ticker_1, ticker_2] = tickers} do
    assert [^ticker_1] = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 0, 59}}, 1) |> Repo.all

    assert ^tickers = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 0, 59}}, 1.01) |> Repo.all

    assert [^ticker_1, ^ticker_2] = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 1, 0}}, 1.01) |> Repo.all
  end

  test "in_time_range/4 handles time range offset",
      %{tickers: [_ticker_0, ticker_1, _ticker_2] = tickers} do
    assert ^tickers = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 0, 49}}, 1.01, 10) |> Repo.all

    assert [^ticker_1] = Ticker
    |> in_time_range({{2016, 4, 20}, {12, 59, 49}}, 0.5, 70) |> Repo.all

    assert ^tickers = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 1, 59}}, 1.01, -60) |> Repo.all
  end

  test "changeset/3 for :create sets d_la attribute", %{tickers: tickers} do
    assert_d_la_set = fn [ticker_0, ticker_1, ticker_2] ->
      assert ticker_0.d_la == nil
      assert ticker_1.d_la == (ticker_1.la - ticker_0.la) / ticker_0.la
      assert ticker_2.d_la == (ticker_2.la - ticker_1.la) / ticker_1.la
    end

    assert_d_la_set.(tickers)

    Ticker
    |> in_time_range({{2016, 4, 20}, {13, 0, 0}}, 3600, 0)
    |> Repo.all
    |> assert_d_la_set.()
  end
end
