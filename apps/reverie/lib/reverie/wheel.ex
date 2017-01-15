defmodule Reverie.Wheel do
  use GenServer
  require Logger
  import Process, only: [send_after: 3]
  import Task.Supervisor, only: [async_nolink: 2]
  import Timex, only: [now: 0]
  import Caravan.Wheel.Modes.K15, only: [map_resp: 1]
  import Huo.Market, only: [get: 2]
  import Utils.Time, only: [to_timex: 1]
  import Utils.Number, only: [floor: 1]
  alias Dirk.Ticker.K15
  alias Machine.DataGen
  alias Reverie.TemporaryTaskSup

  @compile {:inline, fetch_data: 0}
  @interval Application.get_env(:reverie, :wheel_interval)
  @half_15min 15 * 60 / 2

  ## API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def target_tl do
    GenServer.call(__MODULE__, :target_tl)
  end

  ## Callbacks

  def init(_) do
    Process.send(self(), :loop, [])
    {:ok, %{}}
  end

  def handle_call(:target_tl, _,
                  %{target_tl: target_tl, fetched_at: fetched_at} = state) do
    {:reply, {target_tl, fetched_at}, state}
  end

  def handle_info(:loop, state) do
    send_after(self(), :loop, @interval)
    %{pid: pid} = async_nolink(TemporaryTaskSup, &pull/0)
    send_after(self(), {:timeout, pid}, @interval - 50)
    {:noreply, state}
  end

  def handle_info({:timeout, pid}, state) do
    if Process.alive?(pid) do
      :ok = Task.Supervisor.terminate_child(TemporaryTaskSup, pid)
      Logger.warn "Timeout in #{__MODULE__}. Task #{inspect pid} terminated."
    end
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, code}, state)
  when code in [:normal, :shutdown] do
    {:noreply, state}
  end

  def handle_info({_ref, {:merge_k15, body}}, state) do
    target_tl =
      body |> map_resp |> merge_k15 |> build_target |> Enum.slice(0..-2)
    {:noreply, Map.merge(state, %{target_tl: target_tl,
                                  fetched_at: Timex.now()})}
  end

  def handle_info(msg, state) do
    Logger.error "#{__MODULE__} received unexpected message: #{inspect msg}"
    {:noreply, state}
  end

  defp merge_k15([%{hi: hi_1, la: _, lo: lo_1, op: op_1, time: time_1,
       vo: vo_1} = _t1, %{hi: hi_0, la: la_0, lo: lo_0, op: _, time: time_0,
       vo: vo_0} = t0]) do
    cond do
      Timex.diff(now(), to_timex(time_0), :seconds) > @half_15min ||
      vo_0 >= vo_1 * 0.67 ->
        {:t0_as_latest, t0}
      true ->
        {:t1_as_latest, %{hi: max(hi_0, hi_1), la: la_0, lo: min(lo_0, lo_1),
                          op: op_1, time: time_1, vo: floor(vo_0 + vo_1)}}
    end
  end

  defp build_target(merged_result) do
    merged_result |> build_data |> DataGen.build_chunks |> hd
  end

  defp build_data({:t0_as_latest, %{la: t0_la} = t0}) do
    [%{la: datum_la}|_] = data = fetch_data()
    d_la = t0_la / datum_la - 1.0
    [struct!(K15, Map.merge(t0, %{id: -1, d_la: d_la}))|data]
  end

  defp build_data({:t1_as_latest, %{la: t1_la} = t1}) do
    [datum_1|[%{la: datum_2_la}|_]=data_tl] = fetch_data()
    d_la = t1_la / datum_2_la - 1.0
    [struct!(datum_1, Map.put(t1, :d_la, d_la))|data_tl]
  end

  defp fetch_data, do: DataGen.fetch_data(0, 500, log: false)

  defp pull do
    {:ok, %{body: body}} = get(:k15_recent, 2)
    {:merge_k15, body}
  end
end

