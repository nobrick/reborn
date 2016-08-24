defmodule Azor.Ords.WatcherTest do
  use ExUnit.Case, async: true
  import Azor.Ords.Watcher, only: [satisfy?: 3]

  defmodule Manager do
    use GenServer

    def init(:ok) do
      {:ok, %{ords: %{0 => %{status: :completed},
                      1 => %{status: :pending},
                      2 => %{status: :completed}}}}
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

  def start_manager(_context) do
    {:ok, manager} = GenServer.start_link(Manager, :ok)
    {:ok, %{state: %{ords_manager: manager}}}
  end
end
