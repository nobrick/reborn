alias Experimental.GenStage

defmodule Azor.Ords.Watcher do
  use GenStage
  alias Azor.Ords.Manager
  alias Caravan.Wheel.Simple.Broadcaster

  @conditions [:la_above_p, :la_below_p]

  def start_link(%{ord: _, condition: condition} = args, opts \\ [])
      when condition in @conditions do
    args = Map.put_new(args, :ords_manager, Manager)
    GenStage.start_link(__MODULE__, args, opts)
  end

  def permitted_conds, do: @conditions

  ## Callbacks

  def init(args) do
    {:consumer, args, subscribe_to: [Broadcaster]}
  end

  def handle_events(events, _from, %{ord: %{id: id}, condition: condition,
                                     ords_manager: manager} = state) do
    for event <- events do
      {:after_fetch, :simple, ret} = event
      case ret do
        {:ok, ticker} ->
          if satisfy?(ticker, condition, state) do
            Manager.sync_ord(manager, id, :processing, %{ticker: ticker})
            GenStage.stop(self)
          end
        error ->
          IO.inspect error
      end
    end
    {:noreply, [], state}
  end

  def satisfy?(ticker, condition, state)
  def satisfy?(%{la: la}, :la_above_p, %{ord: %{p: p}}), do: la >= p
  def satisfy?(%{la: la}, :la_below_p, %{ord: %{p: p}}), do: la <= p
end
