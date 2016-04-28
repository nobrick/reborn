defmodule Dirk.TickerTest do
  use ExUnit.Case, async: true
  import Ecto.DateTime, only: [cast!: 1]
  import Dirk.Ticker, only: [in_time_range: 3, in_time_range: 4]
  alias Ecto.Adapters.SQL.Sandbox
  alias Dirk.Ticker
  alias Dirk.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
    for time_part <- [{13, 0, 58}, {13, 0, 59}, {13, 1, 0}] do
      time = {{2016, 4, 20}, time_part}
      ticker = %Ticker{op: 2900.0, la: 3000.0, hi: 3100.0, lo: 2800.0,
                       vo: 1600000.0, of: 3000.0, bi: 3000.0, d_la: 0.00001,
                       time: cast!(time)}
      Repo.insert(ticker)
    end
    :ok
  end

  test "in_time_range/4 returns the expected query" do
    assert [%Ticker{}] = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 0, 59}}, 1) |> Repo.all

    assert [%Ticker{}, %Ticker{}, %Ticker{}] = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 0, 59}}, 1.01) |> Repo.all

    assert [%Ticker{}, %Ticker{}] = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 1, 0}}, 1.01) |> Repo.all
  end

  test "in_time_range/4 handles time range offset" do
    assert [%Ticker{}, %Ticker{}, %Ticker{}] = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 0, 49}}, 1.01, 10) |> Repo.all

    assert [%Ticker{}] = Ticker
    |> in_time_range({{2016, 4, 20}, {12, 59, 49}}, 0.5, 70) |> Repo.all

    assert [%Ticker{}, %Ticker{}, %Ticker{}] = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 1, 59}}, 1.01, -60) |> Repo.all
  end
end
