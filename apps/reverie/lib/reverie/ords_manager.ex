defmodule Reverie.OrdsManager do
  @moduledoc """
  Ords tracker.
  """
  use GenServer
  require Logger
  import Process, only: [send_after: 3]
  import Task.Supervisor, only: [async_nolink: 2, async_stream_nolink: 4]
  alias Huo.Order, as: Client
  alias Reverie.{Database.Ord, TemporaryTaskSup}

  @interval 1500

  ## API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def get_ords do
    GenServer.call(__MODULE__, :get_ords)
  end

  def cancel_all do
    GenServer.call(__MODULE__, :cancel_all)
  end

  ## Callbacks

  def init(_) do
    Process.send(self(), :loop, [])
    {:ok, %{}}
  end

  def handle_call(:get_ords, _,
                  %{ongoing_ords: ords, fetched_at: fetched_at} = state) do
    {:reply, {ords, fetched_at}, state}
  end

  def handle_call(:cancel_all, _, %{ongoing_ords: ords} = state) do
    stream =
      async_stream_nolink(TemporaryTaskSup, ords, fn %{"id" => id} ->
        Client.cancel_ord(id)
      end, max_concurrency: 4)
    {:reply, Enum.to_list(stream), state}
  end

  def handle_info(:loop, state) do
    send_after(self(), :loop, @interval)
    %{pid: pid} = async_nolink(TemporaryTaskSup, &query_ongoing_ords/0)
    send_after(self(), {:timeout, pid}, @interval - 50)
    {:noreply, state}
  end

  def handle_info({:timeout, pid}, state) do
    if Process.alive?(pid) do
      :ok = Task.Supervisor.terminate_child(TemporaryTaskSup, pid)
      Logger.warn "Timeout in #{__MODULE__}. State: #{inspect state}" <>
      " Task #{inspect pid} terminated."
    end
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, code}, state)
  when code in [:normal, :shutdown] do
    {:noreply, state}
  end

  def handle_info({_ref, {:query_ok, new_state}}, _state) do
    {:noreply, new_state}
  end

  def handle_info(msg, state) do
    Logger.error "#{__MODULE__} received unexpected message: #{inspect msg}"
    {:noreply, state}
  end

  defp sync_ord(ord_id) do
    case Client.get_ords do
      {:ok, resp} ->
        {:sync_ord_ok, Ord.write_by_resp!(resp)}
      err ->
        Logger.warn("Client.get_ords/0 failed: #{inspect err}")
        :sync_ord_error
    end
  end

  defp query_ongoing_ords do
    case Client.get_ords do
      {:ok, ongoing_ords} ->
        {:query_ok, %{ongoing_ords: ongoing_ords, fetched_at: Timex.now()}}
      err ->
        Logger.warn("Client.get_ords/0 failed: #{inspect err}")
        :query_error
    end
  end
end
