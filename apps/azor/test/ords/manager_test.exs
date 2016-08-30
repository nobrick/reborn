defmodule Azor.Ords.ManagerTest do
  use ExUnit.Case, async: true
  alias Azor.Ords.Manager
  alias Caravan.Wheel.Broadcaster
  import Manager, only: [init: 1, handle_call: 3, get_ord: 2]

  @non_exist_id 404

  defmodule OrdClient do
    def bi_mkt(_amt) do
      {:ok, %{"id" => random, "result" => "success"}}
    end

    def of_mkt(_amt) do
      {:ok, %{"id" => random, "result" => "success"}}
    end

    defp random do
      :rand.uniform(1000)
    end
  end

  describe "get_ord/2" do
    test "returns {:ok, ord} if found" do
      state = %{ords: %{0 => :ord_mock}}
      args = {:get_ord, 0}
      assert {:reply, {:ok, :ord_mock}, ^state} = handle_call(args, nil, state)
    end
  end

  describe "get_ord/2 with server starting" do
    setup [:start_manager]

    test "returns :not_exist if not found", %{manager: manager} do
      assert :not_exist = get_ord(manager, @non_exist_id)
      {:ok, state} = init(%{})
      args = {:get_ord, @non_exist_id}
      assert {:reply, :not_exist, ^state} = handle_call(args, nil, state)
    end
  end

  describe "get_ords/2" do
    test "returns ord ids" do
      state = %{ords: %{0 => :ord_1, 1 => :ord_2}}
      args = {:get_ords, [1, 2]}
      assert {:reply, [:ord_2], ^state} = handle_call(args, nil, state)
    end
  end

  describe "get_status/2" do
    test "returns ord status" do
      state = %{ords: %{0 => %{id: 0, status: :completed}}}
      args = {:get_status, 0}
      assert {:reply, :completed, ^state} = handle_call(args, nil, state)

      args = {:get_status, 1}
      assert {:reply, nil, ^state} = handle_call(args, nil, state)
    end
  end

  describe "add_bi/4 and add_of/4" do
  end

  describe "add_bi_mkt/3 and add_of_mkt/3" do
    test "before processing" do
      {:ok, state} = init(%{ord_client: OrdClient})
      args = {:add_bi_mkt, 2, %{cond: {:now}}}
      assert {:reply, {:ok, id}, %{ords: ords}} = handle_call(args, nil, state)
      assert %{^id => %{action: :add_bi_mkt, amt: 2, id: ^id,
                        status: :watched, watch: %{cond: {:now}}}} = ords
    end
  end

  describe "add_bi_mkt/3 and add_of_mkt/3 with server starting" do
    setup [:start_broadcaster, :start_manager]

    test "before_pending", %{manager: manager, broadcaster: broadcaster} do
      {:ok, oid} = Manager.add_bi_mkt(manager, 2, %{cond: {:now}})
      ticker = %{la: 3500}
      broadcaster
      |> Broadcaster.sync_notify({:after_fetch, :simple, {:ok, ticker}})
      assert_receive({:watcher, :satisfied, watcher, ^oid}, 1000)
      Process.monitor(watcher)
      assert_receive({:DOWN, _, :process, ^watcher, _})
    end
  end

  defp start_broadcaster(_context) do
    {:ok, pid} = Broadcaster.start_link
    {:ok, broadcaster: pid}
  end

  defp start_manager(context) do
    args = %{ord_client: OrdClient, test_process: self}
    args = case context[:broadcaster] do
             nil -> args
             b   -> Map.merge(args, %{watcher: %{subscribe_to: b}})
           end
    {:ok, pid} = Manager.start_link(args)
    {:ok, manager: pid}
  end
end
