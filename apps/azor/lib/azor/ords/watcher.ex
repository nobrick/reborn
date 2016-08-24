alias Experimental.GenStage

defmodule Azor.Ords.Watcher do
  use GenStage
  alias Azor.Ords.Manager
  alias Caravan.Wheel.Simple.Broadcaster

  def start_link(%{ord: _} = args, opts \\ []) do
    args = Map.put_new(args, :ords_manager, Manager)
    GenStage.start_link(__MODULE__, args, opts)
  end

  ## Callbacks

  def init(args) do
    {:consumer, args, subscribe_to: [Broadcaster]}
  end

  def handle_events(events, _from, %{ord: %{id: id}, cond: condition,
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

  ## Helpers

  def satisfy?(ticker, condition, state)

  def satisfy?(_ticker, {:now}, _state), do: true
  def satisfy?(%{la: la}, {:la_above_p}, %{ord: %{p: p}}), do: la >= p
  def satisfy?(%{la: la}, {:la_below_p}, %{ord: %{p: p}}), do: la <= p
  def satisfy?(%{la: la}, {:la_above, p}, _), do: la >= p
  def satisfy?(%{la: la}, {:la_below, p}, _), do: la <= p

  def satisfy?(ticker, {:all, sub_conds}, state) do
    Enum.all?(sub_conds, & satisfy?(ticker, &1, state))
  end

  def satisfy?(ticker, {:any, sub_conds}, state) do
    Enum.any?(sub_conds, & satisfy?(ticker, &1, state))
  end

  def satisfy?(_ticker, {:ord, :on_completed, ord_id},
      %{ords_manager: manager}) when is_integer(ord_id) do
    Manager.get_status(manager, ord_id) == :completed
  end

  def satisfy?(ticker, {:ord, :on_completed, ids}, state) when is_list(ids) do
    Enum.all?(ids, & satisfy?(ticker, {:ord, :on_completed, &1}, state))
  end

  def satisfy?(_ticker, {:ord, :in_status, ord_id, status},
      %{ords_manager: manager}) when is_integer(ord_id) do
    Manager.get_status(manager, ord_id) == status
  end

  def satisfy?(ticker, {:ord, :in_status, ids, status}, state)
      when is_list(ids) do
    Enum.all?(ids, & satisfy?(ticker, {:ord, :in_status, &1, status}, state))
  end

  def satisfy?(ticker, {:ord, :in_status, status_ids_map}, state)
      when is_map(status_ids_map) do
    Enum.all?(status_ids_map, fn {status, ids} ->
      satisfy?(ticker, {:ord, :in_status, ids, status}, state)
    end)
  end
end
