alias Experimental.GenStage

defmodule Caravan.Wheel.Broadcaster do
  use GenStage

  ## API

  @doc """
  Starts the broadcaster.
  """
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Sends an event and returns only after the event is dispatched.
  """
  def sync_notify(server, event, timeout \\ 5000) do
    GenStage.call(server, {:notify, event}, timeout)
  end

  ## Callbacks

  def init(:ok) do
    {:producer, {:queue.new, 0}, dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_call({:notify, event}, from, {queue, demand}) do
    queue = :queue.in({from, event}, queue)
    {events, state} = dispatch_events(queue, demand, [])
    {:reply, :ok, events, state}
  end

  def handle_demand(incoming_demand, {queue, demand}) do
    {events, state} = dispatch_events(queue, demand + incoming_demand, [])
    {:noreply, events, state}
  end

  ## Helpers

  defp dispatch_events(queue, demand, events) do
    with d when d > 0 <- demand,
         {{:value, {_from, event}}, queue} <- :queue.out(queue) do
      dispatch_events(queue, demand - 1, [event | events])
    else
      _ -> {Enum.reverse(events), {queue, demand}}
    end
  end
end
