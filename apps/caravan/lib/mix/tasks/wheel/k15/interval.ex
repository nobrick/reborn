defmodule Mix.Tasks.Wheel.K15.Interval do
  use Mix.Task

  @shortdoc "Starts Caravan.Wheel.Interval server on K15"
  def run(_) do
    {:ok, _} = Application.ensure_all_started(:caravan, :permanent)
    {:ok, _} = Caravan.Wheel.Interval.start_link(mode: :k15)
    Process.sleep(:infinity)
  end
end
