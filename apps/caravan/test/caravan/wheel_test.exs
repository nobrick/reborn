defmodule Caravan.WheelTest do
  use ExUnit.Case
  import Ecto.Query, only: [from: 2]
  alias Ecto.Adapters.SQL.Sandbox
  alias Caravan.Wheel
  alias Dirk.Ticker
  alias Dirk.Ticker.K15
  alias Dirk.Repo

  def count(model) do
    (from t in model, select: count(t.id))
    |> Repo.one
  end

  setup do
    :ok = Sandbox.checkout(Repo)
    {:ok, wheel} = Wheel.start_link
    Sandbox.allow(Repo, self(), wheel)
    {:ok, wheel: wheel}
  end

  test "pull/2 :simple", %{wheel: wheel} do
    prev_count = count(Ticker)
    assert {:ok, %Ticker{}} = Wheel.pull(wheel)
    assert count(Ticker) == prev_count + 1
  end

  test "fetch/2 :simple", %{wheel: wheel} do
    prev_count = count(Ticker)
    assert {:ok, %Ticker{}} = Wheel.fetch(wheel)
    assert count(Ticker) == prev_count
  end

  @k15_count 300
  test "pull/2 :k15", %{wheel: wheel} do
    prev_count = count(K15)
    assert {@k15_count, nil} = Wheel.pull(wheel, :k15)
    assert count(K15) == prev_count + @k15_count
    assert %K15{d_la: _} = (from k in K15, limit: 1) |> Repo.one
  end

  test "fetch/2 :k15", %{wheel: wheel} do
    prev_count = count(K15)
    assert {:ok, k15_list} = Wheel.fetch(wheel, :k15)
    assert %{op: _, la: _, hi: _, lo: _, vo: _, time: _} = hd(k15_list)
    assert count(K15) == prev_count
  end
end
