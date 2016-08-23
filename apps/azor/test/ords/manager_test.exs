defmodule Azor.Ords.ManagerTest do
  use ExUnit.Case, async: true
  alias Azor.Ords.Manager
  import Manager, only: [init: 1, handle_call: 3, get_ord: 2]

  @non_exist_id 404

  describe "get_ord/2" do
    test "returns :not_exist if not found" do
      {:ok, manager: manager} = start_manager(nil)
      assert :not_exist = get_ord(manager, @non_exist_id)

      {:ok, state} = init(:ok)
      args = {:get_ord, @non_exist_id}
      assert {:reply, :not_exist, ^state} = handle_call(args, nil, state)
    end

    test "returns {:ok, ord} if found" do
      state = %{ords: %{0 => :ord_mock}}
      args = {:get_ord, 0}
      assert {:reply, {:ok, :ord_mock}, ^state} = handle_call(args, nil, state)
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

  defp start_manager(_context) do
    {:ok, manager} = Manager.start_link
    {:ok, manager: manager}
  end
end
