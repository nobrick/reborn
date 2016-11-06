defmodule Utils.TimeDiffTest do
  use ExUnit.Case, async: true
  import Utils.TimeDiff, only: [compare: 4, compare: 3]

  @t0 "2016-02-29T22:00:00Z"
  @t1 "2016-02-29T22:25:00Z"

  test "compare/3 clause for ISO8601" do
    assert compare(@t0, @t1, 25) == 0
    assert compare(@t0, @t1, 25, :minutes) == 0
    assert compare(@t0, @t1, 20, :minutes) == -1
    assert compare(@t0, @t1, 30, :minutes) == 1
  end

  test "compare/3 clause for Ecto.DateTime" do
    ecto_t0 = Ecto.DateTime.cast!(@t0)
    ecto_t1 = Ecto.DateTime.cast!(@t1)
    assert compare(ecto_t0, ecto_t1, 25, :minutes) == 0
    assert compare(ecto_t0, ecto_t1, 23, :minutes) == -1
    assert compare(ecto_t0, ecto_t1, 27, :minutes) == 1
  end
end
