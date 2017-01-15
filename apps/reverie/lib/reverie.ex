defmodule Reverie do
  @moduledoc """
  Reverie.
  """

  use GenServer
  require Logger
  import Task.Supervisor, only: [async_nolink: 2]
  import Machine.Strategies, only: [seq_r_fun: 4]
  import Machine.DataHelper, only: [la: 1, bias: 2, chunk_elems_in_seq?: 2,
                                    chunk_size: 1]
  import Utils.Number, only: [floor: 1, floor: 2]
  import Reverie.Commander, only: [get_la: 0, get_remote: 0,
                                   run_instruction: 2]
  alias Reverie.{Brain, OrdsManager, TransientTaskSup, TemporaryTaskSup}

  @strategy :gt_0
  @interval Application.get_env(:reverie, :breath_interval)

  ## API

  def start_link(args \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ## Callbacks

  def init(args) do
    Process.send(self(), :loop, [])
    %{nav: nav, la: la} = fetched = get_remote()
    initial_nav = args[:initial_nav] || nav
    initial_la = args[:initial_la] || la
    initial = %{initial_nav: initial_nav, initial_la: initial_la,
                max_nav: initial_nav, min_nav: initial_nav, mdd: 0.0,
                r_fun_acc: %{}, chunk_size: chunk_size(args)}
    {:ok, Map.merge(fetched, next_state(fetched, initial)) |> IO.inspect}
  end

  def handle_info(:loop, state) do
    Process.send_after(self(), :loop, @interval)
    Logger.debug "Syncing remote..."
    async_nolink(TransientTaskSup, fn -> breath(state) end)
    {:noreply, state, 2_000}
  end

  def handle_info({_ref, {:synced, new_state}}, _state) do
    Logger.debug "Predicting..."
    async_nolink(TemporaryTaskSup, fn -> think(new_state) end)
    {:noreply, new_state, 2_000}
  end

  def handle_info({_ref, {:learned, new_state}}, _state) do
    Logger.debug "Making decisions..."
    async_nolink(TransientTaskSup, fn -> decide(new_state) end)
    {:noreply, new_state}
  end

  def handle_info({_ref, {:decided, new_state}}, _state) do
    Logger.debug "Running instructions..."
    async_nolink(TransientTaskSup, fn -> order(new_state) end)
    {:noreply, new_state, 2_000}
  end

  def handle_info({_ref, {:done, new_state}}, _state) do
    {:noreply, new_state |> IO.inspect}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    Logger.error "Timeout in #{__MODULE__}.\n#{inspect state}"
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.error "#{__MODULE__} received unexpected message: #{inspect msg}"
    {:noreply, state}
  end

  defp breath(state) do
    {:synced, next_state(get_remote(), state)}
  end

  defp think(%{chunk_size: chunk_size} = state) do
    {:ok, [c1|_] = target_tl} = fetch_target_tl(chunk_size)
    samples = Reverie.SamplesCache.samples()
    {_, p, _} = Brain.predict(target_tl, samples)[:pred] |> IO.inspect
    p_la = p && floor(la(c1) * (1 + p), 2)
    {:learned, Map.merge(state, %{last_p: p, last_p_la: p_la})}
  end

  defp decide(%{last_p: p, chunk_size: chunk_size} = state) do
    {:ok, target_tl} = fetch_target_tl(chunk_size)
    decision = seq_r_fun(@strategy, p, target_tl, state) |> IO.inspect
    {:decided, Map.merge(state, :proposed_decision, decision)}
  end

  defp order(%{proposed_decision: decision, last_p_la: p_la,
               pft: pft, chunk_size: chunk_size} = state) do
    instruction = decision[:go]
    r_fun_acc = decision[:r_fun_acc]
    latest_la = get_la()
    {:ok, [c1|_]} = fetch_target_tl(chunk_size)
    IO.inspect [target_tl_la: la(c1), p_la: p_la, latest: latest_la]

    #case instruction do
      #:bi_all ->
        #if curr_la <= p_la do
          #{:bi_all_p, curr_la}
        #else
          #{:remain, :bi_all_set, :"curr_la > p_la", [curr_la, p_la]}
        #end

      #:of_all ->
      #_ ->
        #nil
    #end

    #result =
      #case OrdsManager.get_ords do
        #{[], _fetched_at} ->
          #case instruction do
            #:bi_all ->
              #if curr_la <= p_la do
                #run_instruction({:bi_all_p, curr_la}, state)
              #else
                #{:remain, :bi_all_set, :"curr_la > p_la", [curr_la, p_la]}
              #end
            #:of_all ->
              #if curr_la <= p_la do
                #{:of_all_p, p_la}
              #else
                #{:remain, :of_all_set, :"curr_la > p_la", [curr_la, p_la]}
              #end
            #_ ->
              #run_instruction(instruction, state)
          #end
        #ret ->
          #Logger.warn("Pending ord exists: #{inspect ret}")
          #{:remain, :pending_ord_exists, ret}
      #end
    #Logger.debug "Executed: #{inspect result}, pft: #{pft}"
    #{:done, Map.merge(state, %{last_go: result, r_fun_acc: r_fun_acc})}
    :done
  end

  defp fetch_target_tl(chunk_size) do
    {target_tl, _fetched_at} = Reverie.Wheel.target_tl()
    if chunk_elems_in_seq?(target_tl, chunk_size - 1) do
      {:ok, target_tl}
    else
      Logger.error "Target tail chunk_elems_in_seq failed: #{target_tl}"
      {:error, :not_in_seq}
    end
  end

  defp next_state(%{holds: _, ba: _, la: next_la, nav: next_nav} = next,
       %{initial_nav: initial_nav, initial_la: initial_la,
         max_nav: curr_max_nav, min_nav: curr_min_nav,
         mdd: curr_mdd} = curr_state) do
    next_pft = bias(next_nav, initial_nav)
    next_d_la_initial = bias(next_la, initial_la)
    next_max_nav = max(curr_max_nav, next_nav)
    next_min_nav = min(curr_min_nav, next_nav)
    next_dd = - bias(next_nav, next_max_nav)
    next_mdd = max(curr_mdd, next_dd)
    fetched_at = Timex.now()
    derived =
      %{pft: floor(next_pft), d_la_initial: floor(next_d_la_initial),
        max_nav: next_max_nav, min_nav: next_min_nav, dd: floor(next_dd),
        mdd: floor(next_mdd), fetched_at: fetched_at}
    curr_state |> Map.merge(next) |> Map.merge(derived)
  end
end
