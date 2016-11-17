defmodule Machine.Adapters.CloudForest.Backtest do
  @moduledoc """
  A module for backtesting the data.
  """

  use GenServer
  alias Machine.Corr
  alias Machine.Adapters.CloudForest.{Predictor, Trainer}

  ## API

  def start_link(args \\ %{}, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ## Callbacks

  def init(args) do
    {:ok, args}
  end

  ## Helpers

  @filters [{0.82, 35}, {0.8, 37}, {0.78, 39}]

  @doc """
  Backtests for one.
  """
  def test_one(target_chunk, chunks, filters \\ @filters) do
    pattern = target_chunk |> Enum.map(& &1.d_la) |> tl
    corr_chunks = Corr.find_corr_chunks(chunks, pattern, :d_la)
    case Corr.filter_corr_chunks(corr_chunks, filters) do
      {:ok, log, filtered} ->
        Trainer.save_data(filtered |> Stream.map(& elem(&1, 0)))
        Trainer.learn
        Predictor.save_data(target_chunk)
        Predictor.predict
        {:ok, log, Predictor.read_prediction}
      {:error, _} = error ->
        error
    end
  end

  @doc """
  Backtests for all.
  """
  def test_all(target_chunks, lookup_chunks, opts \\ []) do
    fun = fn -> do_test_all(target_chunks, lookup_chunks) end
    if Keyword.get(opts, :tc, true) do
      {time, value} = :timer.tc(fun)
      Map.put(value, :time_elapsed, Float.floor(time / 1.0e6, 1))
    else
      fun.()
    end
  end

  def do_test_all(target_chunks, lookup_chunks) do
    chunks_count = Enum.count(target_chunks)
    result =
      target_chunks
      |> Stream.with_index
      |> Enum.map(fn {target, index} ->
        IO.puts "---- #{index}..#{chunks_count - 1} ----"
        test_one(target, lookup_chunks) |> IO.inspect
      end)
    expections =
      result
      |> Enum.filter_map(fn {:ok, _, _} -> true; {:error, _} -> false end,
                         fn {:ok, _, [_, p, a]} -> calc_ev(p, a) end)
    count_ev = fn n -> expections |> Stream.filter(& &1 == n) |> Enum.count end
    pos_count = count_ev.(1)
    neg_count = count_ev.(-1)
    zero_count = count_ev.(0)
    %{result: result, expections: expections,
      stats: %{chunks_count: chunks_count, pos_count: pos_count,
               neg_count: neg_count, zero_count: zero_count,
               rate: safe_div(pos_count, (pos_count + neg_count))}}
  end

  defp safe_div(a, b) do
    if b == 0 do
      :na
    else
      a / b
    end
  end

  defp calc_ev(predicted, actual, threshold \\ 0.0011) do
    cond do
      abs(predicted) < threshold ->
        0
      actual >= 0 ->
        1
      true ->
        -1
    end
  end
end
