defmodule Dirk.OrdTest do
  use ExUnit.Case, async: true
  alias Dirk.Ord

  test "remote_status/1" do
    assert "no_contract" = Ord.remote_status(0)
    assert "in_queue" = Ord.remote_status(7)
  end

  test "type/1" do
    assert "bi" = Ord.type(1)
    assert "of_mkt" = Ord.type(4)
  end
end
