defmodule Dirk.TickerTest do
  use ExUnit.Case
  import Ecto.DateTime, only: [cast!: 1]
  import Dirk.Ticker, only: [in_time_range: 3]
  alias Ecto.Adapters.SQL.Sandbox
  alias Dirk.Ticker
  alias Dirk.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
    for sec <- [30, 31, 32] do
      time = {{2016, 4, 20}, {13, 00, sec}}
      ticker = %Ticker{op: 2900.0, la: 3000.0, hi: 3100.0, lo: 2800.0,
                       vo: 1600000.0, of: 3000.0, bi: 3000.0, d_la: 0.00001,
                       time: cast!(time)}
      Repo.insert(ticker)
    end
    :ok
  end

  test "in_time_range/3 returns the expected query" do
    assert [%Ticker{}] = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 00, 31}}, 1)
    |> Repo.all

    assert [%Ticker{}, %Ticker{}, %Ticker{}] = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 00, 31}}, 1.01)
    |> Repo.all

    assert [%Ticker{}, %Ticker{}] = Ticker
    |> in_time_range({{2016, 4, 20}, {13, 00, 30}}, 1.01)
    |> Repo.all
  end
end
