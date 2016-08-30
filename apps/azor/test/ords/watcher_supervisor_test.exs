defmodule Azor.Ords.WatcherSupervisorTest do
  use ExUnit.Case, async: true
  alias Azor.Ords.WatcherSupervisor

  test "supervises the watcher" do
    condition = {:la_below, 3010}
    ord = %{id: 3, watch: %{cond: condition}}
    {:ok, pid} = WatcherSupervisor.start_child(%{ord: ord, cond: condition})
    assert is_pid(pid)
  end
end
