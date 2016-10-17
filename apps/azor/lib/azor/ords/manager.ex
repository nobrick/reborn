defmodule Azor.Ords.Manager do
  use GenServer
  import Logger, only: [info: 1]
  import Utils.Access, only: [put_present: 3, put_present: 4]
  alias Azor.Ords.{Tracker, WatcherSupervisor}

  @statuses [:initial, :watched, :processing, :pending, :completed, :void]

  ## API

  @doc """
  Starts Azor.Ords.Manager instance.

  ## Options

    * `:ord_client` - The huo order client module. Defaults to `Huo.Order`.
      This option is useful for testing.
  """
  def start_link(args \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Adds bi watch.

  Examples:

      iex> Manager.add_bi(Manager, 3000, 0.01, %{cond: {:la_below, 3010}})
      {:ok, 7}

      iex> Manager.add_bi(Manager, 3000, 0.01, %{cond: {:la_below_p}})
      {:ok, 8}
  """
  def add_bi(server, p, amt, watch) do
    GenServer.call(server, {:add_bi, p, amt, watch})
  end

  @doc """
  Adds of watch.
  """
  def add_of(server, p, amt, watch) do
    GenServer.call(server, {:add_of, p, amt, watch})
  end

  @doc """
  Adds bi_mkt watch.

  Note the `cny_amt` argument takes cny unit.
  """
  def add_bi_mkt(server, cny_amt, watch) do
    GenServer.call(server, {:add_bi_mkt, cny_amt, watch})
  end

  @doc """
  Adds of_mkt watch.
  """
  def add_of_mkt(server, amt, watch) do
    GenServer.call(server, {:add_of_mkt, amt, watch})
  end

  @doc """
  Adds batch commands.

  Examples:

      iex> Manager.batch(Manager, {{:on_completed,
                         {:add_bi, 3010, 0.01, %{cond: {:now}}}},
                         [{:add_of_mkt, 0.01, %{cond: {:la_below_p}}},
                          {:add_of, 3020, 0.01, %{cond: {:now}}}]})
  """
  def batch(server, args) do
    GenServer.call(server, {:batch, args})
  end

  @doc """
  Syncs ord status.
  """
  def sync_ord(server, id, status, info \\ %{}) when status in @statuses do
    GenServer.call(server, {:sync_ord, id, status, info})
  end

  @doc """
  Cancels ord and terminates the associated watcher/tracker instances.

  This function will cancel ord remotely if possible.
  """
  def cancel_ord(server, id) do
    GenServer.call(server, {:cancel_ord, id})
  end

  @doc """
  Get ord.

  Returns {:ok, id} if ord is found, :not_exist otherwise.
  """
  def get_ord(server, id) do
    GenServer.call(server, {:get_ord, id})
  end

  @doc """
  Get ords.
  """
  def get_ords(server, ids) do
    GenServer.call(server, {:get_ords, ids})
  end

  @doc """
  Get ord status.

  Returns an atom if ord is found, nil otherwise.
  """
  def get_status(server, id) do
    GenServer.call(server, {:get_status, id})
  end

  @doc """
  Inspect state.
  """
  def inspect_state(server) do
    GenServer.call(server, {:inspect_state})
  end

  ## Callbacks

  def init(args) do
    state = %{ords:         %{},
              ords_count:   0,
              ord_client:   Map.get(args, :ord_client, Huo.Order),
              test_process: Map.get(args, :test_process),
              p_context:    Map.get(args, :p_context)}
    state = put_present(state, :watcher, args[:watcher][:subscribe_to],
                        & %{subscribe_to: &1})
    {:ok, state}
  end

  def handle_call({action, p, amt, watch}, _from, state)
      when action in [:add_bi, :add_of] do
    {id, state} = add_ord(state, %{p: p, amt: amt, action: action,
                                   watch: watch})
    {:reply, {:ok, id}, state}
  end

  def handle_call({action, amt, watch}, _from, state)
      when action in [:add_bi_mkt, :add_of_mkt] do
    {id, state} = add_ord(state, %{action: action, amt: amt, watch: watch})
    {:reply, {:ok, id}, state}
  end

  def handle_call({:sync_ord, id, status, info}, _from, state) do
    %{status: org_status} = ord = get_in(state, [:ords, id])
    {:reply, :ok, transition(state, ord, {org_status, status}, info)}
  end

  def handle_call({:cancel_ord, id}, _from, state) do
    WatcherSupervisor.terminate_child(id, Map.get(state, :p_context))
    {:reply, :ok, update_status(state, id, :void)}
  end

  def handle_call({:get_ord, id}, _from, %{ords: ords} = state) do
    reply = case Map.get(ords, id) do
              nil -> :not_exist
              ord -> {:ok, ord}
            end
    {:reply, reply, state}
  end

  def handle_call({:get_ords, ids}, _from, %{ords: ords} = state) do
    {:reply, Map.take(ords, ids) |> Map.values, state}
  end

  def handle_call({:get_status, id}, _from, state) do
    {:reply, get_in(state, [:ords, id, :status]), state}
  end

  def handle_call({:inspect_state}, _from, state) do
    info(inspect(state))
    {:reply, :ok, state}
  end

  def handle_info({:process_ord, id}, state) do
    {:noreply, process_ord(state, id)}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  ## Helpers

  defp add_ord(%{ords_count: id} = state, ord) do
    ord = Map.merge(ord, %{id: id, status: :initial})
    {id, state
         |> put_in([:ords, id], ord)
         |> transition(ord, {:initial, :watched}, [])
         |> update_in([:ords_count], &(&1+1))}
  end

  defp transition(%{test_process: test_process} = state, %{id: id,
       watch: %{cond: condition}} = ord, {:initial, :watched}, _info) do
    args = %{ord: ord, cond: condition, test_process: test_process}
           |> put_present(:ords_manager, test_process, self)
           |> put_present(:subscribe_to, state[:watcher][:subscribe_to])
           |> put_present(:p_context, state[:p_context])
    {:ok, _pid} = WatcherSupervisor.start_child(args)
    update_status(state, id, :watched)
  end

  defp transition(state, %{id: id} = _ord, {:watched, :processing}, _info) do
    send(self, {:process_ord, id})
    update_status(state, id, :processing)
  end

  defp transition(state, %{id: id} = ord, {:processing, :pending},
                  %{remote_id: remote_id}) do
    Tracker.start_link(%{ord: Map.put(ord, :remote_id, remote_id)})
    state
    |> update_attr(id, :remote_id, remote_id)
    |> update_status(id, :pending)
  end

  defp transition(state, %{id: id} = _ord, {:pending, :completed}, info) do
    state
    |> update_attr(id, :info, info)
    |> update_status(id, :completed)
  end

  defp transition(state, %{id: id} = _ord, {last_ok_status, :void}, info) do
    state
    |> update_attr(id, :last_ok_status, last_ok_status)
    |> update_attr(id, :info, info)
    |> update_status(id, :void)
  end

  defp update_status(state, ord_id, status) when status in @statuses do
    state = put_in(state, [:ords, ord_id, :status], status)
    IO.inspect(state)
    state
  end

  def update_attr(state, ord_id, attr, value) do
    put_in(state, [:ords, ord_id, attr], value)
  end

  defp process_ord(%{ord_client: client} = state, id) do
    ord = get_in(state, [:ords, id])
    case do_process_ord(client, ord) do
      {:ok, %{"id" => remote_id, "result" => "success"}} ->
        args = %{remote_id: remote_id}
        transition(state, ord, {:processing, :pending}, args)
      error ->
        transition(state, ord, {:processing, :void}, %{error: error})
    end
  end

  defp do_process_ord(client, %{action: :add_bi, p: p, amt: amt}) do
    client.bi(p, amt)
  end

  defp do_process_ord(client, %{action: :add_of, p: p, amt: amt}) do
    client.of(p, amt)
  end

  defp do_process_ord(client, %{action: :add_bi_mkt, amt: amt}) do
    client.bi_mkt(amt)
  end

  defp do_process_ord(client, %{action: :add_of_mkt, amt: amt}) do
    client.of_mkt(amt)
  end
end
