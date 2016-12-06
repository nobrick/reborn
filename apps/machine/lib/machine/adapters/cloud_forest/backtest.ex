defmodule Machine.Adapters.CloudForest.Backtest do
  @moduledoc """
  A module for backtesting the data.
  """

  alias Experimental.Flow
  alias Machine.Corr
  alias Machine.Adapters.CloudForest.{Predictor, Trainer}

  @filters Application.get_env(:machine, :corr_filters)
  @data_storage_path Application.get_env(:machine, :data_storage_path)
  @ev_threshold 0.00388
  @profit_threshold 0.00388
  @stages_num 4

  @doc """
  Backtests for one.
  """
  def test_one(dir_path, target_chunk, chunks, opts) do
    filters = Keyword.get(opts, :filters, @filters)
    pattern = target_chunk |> Enum.map(& &1.d_la) |> tl
    corr_chunks = Corr.find_corr_chunks(chunks, pattern, :d_la)
    case Corr.filter_corr_chunks(corr_chunks, filters) do
      {:ok, logs, filtered} ->
        Trainer.save_data(dir_path, filtered |> Stream.map(& elem(&1, 0)))
        Trainer.learn(dir_path)
        Predictor.save_data(dir_path, target_chunk)
        Predictor.predict(dir_path)
        {:ok, logs, Predictor.read_prediction(dir_path)}
      {:error, _} = error ->
        error
    end
  end

  @doc """
  Backtests for all.
  """
  def test_all(target_chunks, lookup_chunks, opts \\ []) do
    {check_conflict?, opts} =
      Keyword.pop(opts, :check_target_lookup_conflicts, true)
    if check_conflict? do
      range = fn chunks ->
        [List.last(List.last(chunks)).time,
         hd(hd(chunks)).time,
         Enum.count(chunks)]
      end
      # TODO: Checks if the two periods conflict each other instead of
      # outputing results.
      range.(lookup_chunks) |> IO.inspect
      range.(target_chunks) |> IO.inspect
    end

    {measure_time?, opts} = Keyword.pop(opts, :tc, true)
    fun = fn -> do_test_all(target_chunks, lookup_chunks, opts) end
    if measure_time? do
      {time, value} = :timer.tc(fun)
      Keyword.put(value, :time_elapsed, Float.floor(time / 1.0e6, 1))
    else
      fun.()
    end
  end

  defp do_test_all(target_chunks, lookup_chunks, opts) do
    target_chunks_count = Enum.count(target_chunks)
    data_dir_path = make_data_dir
    result =
      target_chunks
      |> Stream.with_index
      |> Flow.from_enumerable
      |> Flow.partition(stages: @stages_num)
      |> Flow.map(fn {target, index} ->
        IO.puts "---- #{index}..#{target_chunks_count - 1} ----"
        subdir_path = Path.join(data_dir_path, Integer.to_string(index))
        File.mkdir!(subdir_path)
        test_one(subdir_path, target, lookup_chunks, opts) |> IO.inspect
      end)
      |> Enum.to_list
    p_a_list = Enum.filter_map(result,
                 fn {:ok, _, _} -> true; {:error, _} -> false end,
                 fn {:ok, _, [_, p, a]} -> {p, a} end)
    all_samples_profit =
      target_chunks
      |> Enum.reduce(1, fn chunk, acc ->
        (hd(chunk).d_la + 1) * acc
      end)
      |> (& {&1 - 1, target_chunks_count}).()
    profit_spectrum = get_profit_spectrum(p_a_list)
    [result: result, p_a_list: p_a_list, profit_spectrum: profit_spectrum,
     corr_filters: get_corr_filters_stats(result),
     stats: [target_chunks_count: target_chunks_count],
     profit_min_max: Enum.min_max_by(profit_spectrum, & elem(&1, 2)),
     profit: [gt_threshold: profit(p_a_list),
              gt_0: profit(p_a_list, & &1 > 0),
              lt_0: profit(p_a_list, & &1 < 0),
              all_learned: profit(p_a_list, fn _ -> true end),
              all_samples: all_samples_profit]]
    |> Keyword.update!(:stats, & Keyword.merge(&1, count_ev(p_a_list)))
  end

  defp make_data_dir do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time
    path = Path.join(@data_storage_path, "#{y}-#{m}-#{d}-#{hh}-#{mm}-#{ss}")
    File.mkdir!(path)
    path
  end

  @doc """
  Counts expection values.
  """
  def count_ev(p_a_list, calc_ev_fun \\ &calc_ev/2) do
    expections = Enum.map(p_a_list, fn {p, a} -> calc_ev_fun.(p, a) end)
    count = fn n -> expections |> Stream.filter(& &1 == n) |> Enum.count end
    pos_count = count.(1)
    neg_count = count.(-1)
    zero_count = count.(0)
    [pos_count: pos_count,
     neg_count: neg_count,
     zero_count: zero_count,
     rate: safe_div(pos_count, (pos_count + neg_count))]
  end

  @doc """
  Calculates the profit expectation given the prediction value filter `p_fun`.
  """
  def profit(p_a_list, p_fun \\ &(&1 >= @profit_threshold)) do
    p_a_list
    |> Enum.filter(fn {p, _} -> p_fun.(p) end)
    |> Enum.reduce({1, 0}, fn {_, a}, {value, count} ->
      {value * (1 + a), count + 1}
    end)
    |> (fn {value, count} -> {value - 1, count} end).()
  end

  def get_profit_spectrum(p_a_list) do
    reduce = fn {p, a}, {list, value, count, pos_pft_count} -> 
      value = value * (1 + a)
      profit = value - 1
      count = count + 1
      pos_pft_count =
        if profit > 0 do
          pos_pft_count + 1
        else
          pos_pft_count
        end
      pos_pft_rate = safe_div(pos_pft_count, count)
      {[{p, a, profit, count, pos_pft_count, pos_pft_rate}|list],
       value, count, pos_pft_count}
    end
    p_a_list
    |> Enum.sort_by(fn {p, _} -> p end, &>=/2)
    |> Enum.reduce({[], 1, 0, 0}, reduce)
    |> (& elem(&1, 0)).()
    |> Enum.sort_by(& elem(&1, 2), &>=/2)
  end

  defp get_corr_filters_stats(result) do
    result
    |> Enum.flat_map(& elem(&1, 1))
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      Map.update(acc, k, {0, 0}, fn {sum, n} -> {sum + v, n + 1} end)
    end)
    |> Enum.map(fn {k, {sum, n}} -> {k, safe_div(sum, n, 1)} end)
  end

  defp safe_div(a, b, precision \\ 6) do
    if b == 0 do
      :na
    else
      Float.round(a / b, precision)
    end
  end

  defp calc_ev(predicted, actual, threshold \\ @ev_threshold) do
    cond do
      predicted >= threshold && actual >= 0 ->
        1
      predicted >= threshold ->
        -1
      predicted < -threshold && actual < 0 ->
        1
      predicted < -threshold ->
        -1
      true ->
        0
    end
  end
end
