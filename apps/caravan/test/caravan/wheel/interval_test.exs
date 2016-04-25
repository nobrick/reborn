defmodule Caravan.Wheel.IntervalTest do
  use ExUnit.Case
  alias Ecto.Adapters.SQL.Sandbox
  alias Caravan.Wheel
  alias Caravan.Wheel.Interval
  alias Dirk.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
    {:ok, wheel} = Wheel.start_link
    Sandbox.allow(Repo, self(), wheel)
    {:ok, interval_sup} = Task.Supervisor.start_link
    {:ok, wheel: wheel, interval_sup: interval_sup, pulling_interval: 1000, test_process: self()}
  end

  test "start_link/2 pulls at a regular interval", context do
    opts = context
    |> Map.take([:wheel, :interval_sup, :pulling_interval, :test_process])
    |> Map.to_list
    {:ok, _interval} = Interval.start_link(opts)
    for _ <- 1..3 do
      assert_receive {:start_child, pid}, 3000
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, _, :normal}, 3000
    end
  end
end
