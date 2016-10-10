defmodule Azor.Ords.WatcherTest do
  use ExUnit.Case, async: true
  import Azor.Ords.Watcher, only: [satisfy?: 3]
  import Utils.Access, only: [put_present: 3, put_present: 4]
  import Caravan.Wheel.Broadcaster, only: [sync_notify: 2]
  import Azor.TestHelper, only: [kill_on_exit: 1]
  alias Caravan.Wheel.Broadcaster
  alias Azor.Ords.Watcher

  defmodule Manager do
    use GenServer

    def init(args \\ %{}) do
      broadcaster = args[:watcher][:subscribe_to]
      state = %{ords: %{0 => %{id: 0, status: :completed},
                        1 => %{id: 1, status: :pending},
                        2 => %{id: 2, status: :completed},
                        3 => %{id: 3, status: :watched}}}
      state = put_present(state, [:watcher], broadcaster,
                          & %{subscribe_to: &1})
      {:ok, state}
    end

    def handle_call(request, from, state) do
      Azor.Ords.Manager.handle_call(request, from, state)
    end
  end

  describe "satisfy?/3 non :ord clausess" do
    test "{:now}" do
      assert satisfy?(nil, {:now}, nil)
    end

    test "{:la_above, p}" do
      assert satisfy?(%{la: 4001.11}, {:la_above, 4001.11}, nil)
      assert satisfy?(%{la: 4001}, {:la_above, 4000}, nil)
      refute satisfy?(%{la: 4001}, {:la_above, 4002}, nil)
    end

    test "{:la_below, p}" do
      assert satisfy?(%{la: 4001.11}, {:la_below, 4001.11}, nil)
      assert satisfy?(%{la: 4001}, {:la_below, 4002}, nil)
      refute satisfy?(%{la: 4001}, {:la_below, 4000}, nil)
    end

    test "{:all, sub_conds}" do
      assert satisfy?(%{la: 4001}, {:all, [{:la_above, 4000},
                                          {:la_below, 4002}]}, nil)
      refute satisfy?(%{la: 4001}, {:all, [{:la_above, 4000},
                                          {:la_below, 4000.99}]}, nil)
    end

    test "{:any, sub_conds}" do
      assert satisfy?(%{la: 4001}, {:any, [{:la_above, 4000},
                                          {:la_above, 4002}]}, nil)
      refute satisfy?(%{la: 4001}, {:any, [{:la_above, 4002},
                                          {:la_below, 4000}]}, nil)
    end
  end

  describe "satisfy?/3 :ord clauses" do
    setup [:start_manager]

    test "{:ord, :on_completed, ord_id}", %{state: state} do
      assert satisfy?(nil, {:ord, :on_completed, 0}, state)
      refute satisfy?(nil, {:ord, :on_completed, 1}, state)
      refute satisfy?(nil, {:ord, :on_completed, 11}, state)
    end

    test "{:ord, :in_status, ord_id, status}", %{state: state} do
      assert satisfy?(nil, {:ord, :in_status, 0, :completed}, state)
      refute satisfy?(nil, {:ord, :in_status, 1, :completed}, state)
      refute satisfy?(nil, {:ord, :in_status, 11, :completed}, state)
    end

    test "{:ord, :on_completed, ids}", %{state: state} do
      assert satisfy?(nil, {:ord, :on_completed, [0, 2]}, state)
      refute satisfy?(nil, {:ord, :on_completed, [0, 1]}, state)
      refute satisfy?(nil, {:ord, :on_completed, [0, 11]}, state)
    end

    test "{:ord, :in_status, ids, status}", %{state: state} do
      assert satisfy?(nil, {:ord, :in_status, [0, 2], :completed}, state)
      refute satisfy?(nil, {:ord, :in_status, [0, 1], :completed}, state)
      refute satisfy?(nil, {:ord, :in_status, [0, 11], :completed}, state)
    end

    test "{:ord, :in_status, status_ids_map}", %{state: state} do
      assert satisfy?(nil, {:ord, :in_status, %{completed: [0, 2],
                      pending: [1]}}, state)
      refute satisfy?(nil, {:ord, :in_status, %{completed: [0, 1]}}, state)
      refute satisfy?(nil, {:ord, :in_status, %{completed: [0, 2],
                      pending: [1, 11]}}, state)
    end
  end

  describe "watcher" do
    setup [:start_broadcaster, :start_manager, :start_watcher]

    test "terminates itself when satisfied", %{watcher: watcher,
                                               broadcaster: broadcaster} do
      ticker = %{la: 3000}
      sync_notify(broadcaster, {:after_fetch, :simple, {:ok, ticker}})
      assert_receive({:watcher, :satisfied, ^watcher, _oid}, 1000)
      ref = Process.monitor(watcher)
      assert_receive({:DOWN, ^ref, :process, ^watcher, _})
    end
  end

  defp start_broadcaster(_context) do
    {:ok, pid} = Broadcaster.start_link
    kill_on_exit(pid)
    {:ok, broadcaster: pid}
  end

  defp start_manager(context) do
    args =
      %{}
      |> put_present([:watcher], context[:broadcaster], & %{subscribe_to: &1})
      |> Map.put(:p_context, context[:test])
    {:ok, pid} = GenServer.start_link(Manager, args)
    kill_on_exit(pid)
    {:ok, %{state: %{ords_manager: pid}, manager: pid}}
  end

  defp start_watcher(context) do
    args =
      %{ord: %{id: 3}, cond: {:now}, test_process: self}
      |> put_present([:ords_manager], context[:manager])
      |> put_present([:subscribe_to], context[:broadcaster])
      |> Map.put(:p_context, context[:test])
    {:ok, pid} = Watcher.start_link(args)
    kill_on_exit(pid)
    {:ok, watcher: pid}
  end
end
