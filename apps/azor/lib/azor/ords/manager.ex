defmodule Azor.Ords.Manager do
  use GenServer
  alias Azor.Ords.Watcher

  @statuses [:initial, :watched, :processing, :completed, :void]

  ## API

  # @watch_conds Module.get_attribute(Watcher, :conditions)
  @watch_conds [:la_above_p, :la_below_p]

  @doc """
  Starts Azor.Ords.Manager instance.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Sets bi watch.
  """
  def set_bi(server, p, amt, watch_cond) when watch_cond in @watch_conds do
    GenServer.call(server, {:set_bi, p, amt, %{condition: watch_cond}})
  end

  @doc """
  Sets of watch.
  """
  def set_of(server, p, amt, watch_cond) when watch_cond in @watch_conds do
    GenServer.call(server, {:set_of, p, amt, %{condition: watch_cond}})
  end

  @doc """
  Syncs ord status.
  """
  def sync_ord(server, id, status, info \\ %{}) when status in @statuses do
    GenServer.call(server, {:sync_ord, id, status, info})
  end

  @doc """
  Inspect state.
  """
  def inspect(server) do
    GenServer.call(server, {:inspect})
  end

  ## Callbacks

  def init(:ok) do
    {:ok, %{ords: %{}, ords_count: 0}}
  end

  def handle_call({action, p, amt, %{condition: _} = watch_args}, _from, state)
      when action in [:set_bi, :set_of] do
    ord = %{p: p, amt: amt, action: action, watch: watch_args}
    {:reply, :ok, add_ord(state, ord)}
  end

  def handle_call({:sync_ord, id, status, info}, _from, state) do
    {:reply, :ok, transition(state, id, status, info)}
  end

  def handle_call({:inspect}, _from, state) do
    IO.inspect(state)
    {:reply, :ok, state}
  end

  ## Helpers

  defp add_ord(%{ords_count: id} = state, ord) do
    state
    |> put_in([:ords, id], Map.merge(ord, %{id: id, status: :initial}))
    |> transition(id, :watched)
    |> update_in([:ords_count], &(&1+1))
  end

  defp transition(state, id, status, info \\ %{})
       when is_integer(id) and is_atom(status) do
    %{status: org_status} = ord = get_in(state, [:ords, id])
    state
    |> do_transition(ord, {org_status, status}, info)
    |> put_in([:ords, id, :status], status)
  end

  defp do_transition(state, %{watch: %{condition: condition}} = ord,
                     {:initial, :watched}, _info) do
    {:ok, _} = Watcher.start_link(%{ord: ord, condition: condition})
    state
  end

  defp do_transition(state, ord, {:watched, :processing}, _info) do
    # TODO: Implement the ord transition between watched and processing state
    # with methods in Huo.Order Module.
    state
  end

  defp do_transition(state, ord, {:processing, :completed}, _info) do
    state
  end

  defp do_transition(state, ord, {_, :void}, _info) do
    state
  end
end
