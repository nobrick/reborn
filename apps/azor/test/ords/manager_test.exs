defmodule Azor.Ords.ManagerTest do
  use ExUnit.Case, async: true
  alias Azor.Ords.{Manager, Watcher}
  alias Caravan.Wheel.Broadcaster
  import Azor.TestHelper, only: [kill_on_exit: 1]
  import Manager, only: [init: 1, handle_call: 3, get_ord: 2]
  import Utils.Access, only: [put_present: 4]

  @non_exist_id 404

  defmodule OrdClient do
    def bi_mkt(_amt) do
      {:ok, %{"id" => random(), "result" => "success"}}
    end

    def of_mkt(_amt) do
      {:ok, %{"id" => random(), "result" => "success"}}
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
    test "before processing", %{test: test} do
      {:ok, state} = init(%{ord_client: OrdClient, p_context: test,
                            test_process: self()})
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
      event = {:after_fetch, :simple, {:ok, ticker}}
      Broadcaster.sync_notify(broadcaster, event)
      assert_receive({:watcher, :satisfied, watcher, ^oid}, 1000)
      ref = Process.monitor(watcher)
      assert_receive({:DOWN, ^ref, :process, ^watcher, _})
    end
  end

  describe "cancel_ord/2" do
    test "transitions into void state" do
      args = {:cancel_ord, 1}
      state = %{ords: %{1 => %{status: :pending}}}
      expected_state = put_in(state, [:ords, 1, :status], :void)
      assert {:reply, :ok, ^expected_state} = handle_call(args, nil, state)
    end
  end

  describe "cancel_ord/2 with server starting" do
    setup [:start_broadcaster, :start_manager]

    test "terminates the associated watcher if alive", %{manager: manager,
                                                         test: test} do
      {:ok, oid} = Manager.add_bi(manager, 3000, 0.01, %{cond: {:now}})
      ref = oid |> Watcher.whereis(test) |> Process.monitor
      Manager.cancel_ord(manager, oid)
      assert_receive({:DOWN, ^ref, :process, _, _})
    end

    test "terminates the associated tracker if alive" do
    end
  end

  defp start_broadcaster(_context) do
    {:ok, pid} = Broadcaster.start_link
    kill_on_exit(pid)
    {:ok, broadcaster: pid}
  end

  defp start_manager(context) do
    args =
      %{ord_client: OrdClient, test_process: self()}
      |> put_present([:watcher], context[:broadcaster], & %{subscribe_to: &1})
      |> Map.put(:p_context, context[:test])
    {:ok, pid} = Manager.start_link(args)
    kill_on_exit(pid)
    {:ok, manager: pid}
  end
end
