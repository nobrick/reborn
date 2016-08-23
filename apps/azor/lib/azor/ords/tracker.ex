defmodule Azor.Ords.Tracker do
  use GenServer
  alias Huo.Order
  alias Azor.Ords.Manager

  @max_interval 64_000
  @max_resps    10

  @doc """
  Starts the ord tracker.
  """
  def start_link(%{ord: %{id: _, remote_id: _}} = args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ## Callbacks

  def init(args) do
    send(self(), :track)
    {:ok, args
          |> Map.put_new(:interval, 1000)
          |> Map.put_new(:ords_manager, Manager)
          |> Map.merge(%{retries: 0, resps: []})}
  end

  def handle_info(:track, %{ord: %{remote_id: remote_id}} = state) do
    resp = get_ord(remote_id)
    state = put_resp(state, resp)
    IO.inspect(state)
    handle_resp(resp, state)
  end

  def handle_info(_, state), do: {:noreply, state}

  ## Helpers

  defp handle_resp({:ok, %{"status" => "done"}} = resp, state) do
    sync_ord(state, :completed, resp)
    {:noreply, state}
  end

  defp handle_resp({:ok, %{"status" => "canceled"}} = resp, state) do
    sync_ord(state, :void, resp)
    {:noreply, state}
  end

  defp handle_resp(_, %{interval: interval} = state) do
    Process.send_after(self, :track, interval)
    {:noreply, incr_retries(state)}
  end

  defp sync_ord(%{ords_manager: manager, ord: %{id: id}}, status, resp) do
    Manager.sync_ord(manager, id, status, %{resp: resp})
  end

  defp incr_retries(%{interval: interval, retries: retries} = state) do
    state = %{state|retries: retries + 1}
    if interval < @max_interval do
      %{state|interval: interval * 2}
    else
      state
    end
  end

  defp put_resp(%{resps: resps} = state, resp) do
    resps = if Enum.count(resps) >= @max_resps do
              List.delete_at(resps, -1)
            else
              resps
            end
    %{state|resps: [resp|resps]}
  end

  defp get_ord(remote_id) do
    Order.get_ord(remote_id)
  end
end
