defmodule Reverie.Commander do
  @moduledoc """
  Reverie commander.
  """

  alias Huo.Order, as: Client
  import Utils.Number, only: [floor: 1, floor: 2]
  alias Reverie.Database.Ord

  @reserved_ba Application.get_env(:reverie, :reserved_ba)
  @reserved_holds Application.get_env(:reverie, :reserved_holds)

  def available_ba(ba) do
    max(ba - @reserved_ba, 0.0)
  end

  def available_holds(holds) do
    max(holds - @reserved_holds, 0.0)
  end

  # todo
  def run_instruction({:transaction, instructions}, state) do
    prepared =
      Enum.map(instructions, fn instruction ->
        prepare_instruction(instruction, state)
      end)
    if Enum.all?(prepared, & elem(&1, 0) == :ok) do
      prepared
      |> Enum.map(fn {:ok, _meta, fun} -> Task.async(fun) end)
      |> Enum.map(&Task.await/1)
    else
      {:remain, prepared}
    end
  end

  # todo
  def run_instruction({:multi, instructions}, state) do
    instructions
    |> Enum.map(fn instruction ->
      Task.async(fn -> run_instruction(instruction, state) end)
    end)
    |> Enum.map(&Task.await/1)
  end

  def run_instruction(instruction, state) do
    case prepare_instruction(instruction, state) do
      {:ok, meta, fun} ->
        {:ok, %{"id" => id, "result" => "success"}} = fun.()
        Ord.write_unfetched!(id)
        {:ok, meta: meta, id: id}
      {:remain, meta} ->
        {:remain, meta: meta}
    end
  end

  def prepare_instruction(:bi_all_mkt, %{ba: ba, la: la} = _state) do
    bi_amt = floor(ba, 2)
    if bi_amt / la > 0.001 do
      {:ok, [:bi_all, bi_amt, la], fn -> Client.bi_mkt(bi_amt) end}
    else
      {:remain, [:bi_all, :insufficient_ba]}
    end
  end

  def prepare_instruction(:of_all_mkt, %{holds: holds, la: la} = _state) do
    of_amt = floor(holds, 4)
    if of_amt > 0.001 do
      {:ok, [:of_all, of_amt, la], fn -> Client.of_mkt(of_amt) end}
    else
      {:remain, [:of_all, :insufficient_holds]}
    end
  end

  def prepare_instruction({:bi_all_p, p}, %{ba: ba, la: la} = _state) do
    bi_amt = floor(ba / la, 2)
    if bi_amt > 0.005 do
      {:ok, [:bi_all, bi_amt, la], fn -> Client.bi(p, bi_amt) end}
    else
      {:remain, [:bi_all, :insufficient_ba]}
    end
  end

  def prepare_instruction({:of_all_p, p}, %{holds: holds, la: la} = _state) do
    of_amt = floor(holds, 4)
    if of_amt > 0.005 do
      {:ok, [:of_all, of_amt, la], fn -> Client.of(p, of_amt) end}
    else
      {:remain, [:of_all, :insufficient_holds]}
    end
  end

  def prepare_instruction(instruction, _) do
    [i_head|i_rest] = i_list = Tuple.to_list(instruction)
    {:remain, if i_head == :remain do
                i_rest
              else
                i_list
              end}
  end

  def get_remote(opts \\ []) do
    {:ok, %{"net_asset" => org_nav,
            "available_btc_display" => org_holds,
            "available_cny_display" => org_ba,
            "frozen_btc_display" => frozen_holds,
            "frozen_cny_display" => frozen_ba}} = Client.get_account
    la = opts[:la] || get_la()
    holds = available_holds(org_holds)
    ba = available_ba(org_ba)
    nav = ba + holds * la
    %{org_holds: org_holds, org_ba: org_ba, org_nav: org_nav,
      frozen_holds: frozen_holds, frozen_ba: frozen_ba,
      holds: floor(holds), ba: floor(ba), la: la, nav: floor(nav, 3)}
  end

  def get_la do
    {:ok, %{body: %{"ticker" => %{"last" => la}}}} = Huo.Market.get(:simple)
    la
  end
end
