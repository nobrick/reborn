defmodule Dirk.Ticker.K15Test do
  use ExUnit.Case, async: true
  import Dirk.Ticker.K15, only: [distinct_on_time: 1]
  alias Dirk.Ticker.K15
  alias Dirk.Repo

  test "distinct_on_time/1" do
    query = distinct_on_time(K15)
    sql_head = ~S{SELECT DISTINCT ON (k0."time")}
    sql_tail = ~S{ORDER BY k0."time" DESC, k0."vo" DESC}
    {sql, []} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
    assert String.starts_with?(sql, sql_head)
    assert String.ends_with?(sql, sql_tail)
  end
end
