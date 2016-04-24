defmodule Caravan.WheelTest do
  use ExUnit.Case
  import Ecto.Query, only: [from: 2]
  alias Ecto.Adapters.SQL.Sandbox
  alias Caravan.Wheel
  alias Dirk.Ticker
  alias Dirk.Repo

  def count_ticker do
    (from t in Ticker, select: count(t.id))
    |> Repo.all
    |> hd
  end

  setup do
    :ok = Sandbox.checkout(Repo)
    {:ok, wheel} = Wheel.start_link
    Sandbox.allow(Repo, self(), wheel)
    {:ok, wheel: wheel}
  end

  test "pull/2 :simple", %{wheel: wheel} do
    prev_count = count_ticker()
    assert {:ok, %Ticker{}} = Wheel.pull(wheel)
    assert count_ticker() == prev_count + 1
  end

  test "fetch/2 :simple", %{wheel: wheel} do
    prev_count = count_ticker()
    assert {:ok, %Ticker{}} = Wheel.fetch(wheel)
    assert count_ticker() == prev_count
  end
end
