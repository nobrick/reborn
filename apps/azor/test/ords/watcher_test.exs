defmodule Azor.Ords.WatcherTest do
  use ExUnit.Case, async: true
  import Azor.Ords.Watcher, only: [satisfy?: 3]

  defmodule Manager do
    use GenServer

    def init(:ok) do
      {:ok, %{ords: %{0 => %{status: :completed},
                      1 => %{status: :pending}}}}
    end

    def handle_call(request, from, state) do
      Azor.Ords.Manager.handle_call(request, from, state)
    end
  end

  describe "satisfy/3" do
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

    test "{:ord, :on_completed, ord_id}" do
      {:ok, manager} = GenServer.start_link(Manager, :ok)
      assert satisfy?(nil, {:ord, :on_completed, 0}, %{ords_manager: manager})
      refute satisfy?(nil, {:ord, :on_completed, 1}, %{ords_manager: manager})
      refute satisfy?(nil, {:ord, :on_completed, 2}, %{ords_manager: manager})
    end

    test "{:ord, :in_status, ord_id, status}" do
      {:ok, manager} = GenServer.start_link(Manager, :ok)
      state = %{ords_manager: manager}
      assert satisfy?(nil, {:ord, :in_status, 0, :completed}, state)
      refute satisfy?(nil, {:ord, :in_status, 1, :completed}, state)
      refute satisfy?(nil, {:ord, :in_status, 2, :completed}, state)
    end
  end
end
