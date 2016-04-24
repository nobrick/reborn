defmodule Caravan.Wheel.IntervalTest do
  use ExUnit.Case
  alias Ecto.Adapters.SQL.Sandbox
  alias Caravan.Wheel
  alias Caravan.Wheel.Interval
  alias Dirk.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
    {:ok, wheel} = Wheel.start_link
    {:ok, interval_sup} = Task.Supervisor.start_link
    {:ok, wheel: wheel, interval_sup: interval_sup}
  end

  # TODO: Get able to test the interval module.
  test "start_link/2 pulls at a regular interval", context do
    opts = context
    |> Map.take([:wheel, :interval_sup])
    |> Map.to_list
    {:ok, interval} = Interval.start_link(opts)
  end
end
