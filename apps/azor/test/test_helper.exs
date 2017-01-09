defmodule Azor.TestHelper do
  import ExUnit.Callbacks, only: [on_exit: 1]

  def kill_on_exit(pid) do
    on_exit(fn -> Process.exit(pid, :kill) end)
  end

  def gproc_registered do
    match_head = :_
    guard = []
    result = [:'$$']
    [{match_head, guard, result}]
    |> :gproc.select
    |> Enum.filter(& match?([{:n, :l, _}|_], &1))
  end

  def gproc_unregister_all do
    names = Enum.map(gproc_registered(), fn [{_, _, k}|_] -> k end)
    :gproc.munreg(:n, :l, names)
  end

  def gproc_stop_all_registered do
    gproc_registered()
    |> Enum.map(fn [_, pid, _] -> pid end)
    |> Enum.each(& Process.exit(&1, :kill))
  end
end

ExUnit.start()
