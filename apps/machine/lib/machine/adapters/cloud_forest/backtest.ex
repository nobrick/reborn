defmodule Machine.Adapters.CloudForest.Backtest do
  @moduledoc """
  A module for backtesting the data.
  """

  alias Experimental.Flow
  alias Machine.Corr
  alias Machine.Adapters.CloudForest.{Predictor, Trainer}

  @filters Application.get_env(:machine, :corr_filters)
  @data_storage_path Application.get_env(:machine, :data_storage_path)
  @ev_threshold 0.0011
  @profit_threshold 0.0011
  @stages_num 4

  @doc """
  Backtests for one.
  """
  def test_one(dir_path, target_chunk, chunks, filters \\ @filters) do
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
    if Keyword.get(opts, :check_target_lookup_conflicts, true) do
      range = fn chunks ->
        [List.last(List.last(chunks)).time,
         hd(hd(chunks)).time,
         Enum.count(chunks)]
      end
      # TODO: Checks if the two periods conflict each other instead of
      # outputing results.
      range.(target_chunks) |> IO.inspect
      range.(lookup_chunks) |> IO.inspect
    end

    fun = fn -> do_test_all(target_chunks, lookup_chunks) end
    if Keyword.get(opts, :tc, true) do
      {time, value} = :timer.tc(fun)
      Map.put(value, :time_elapsed, Float.floor(time / 1.0e6, 1))
    else
      fun.()
    end
  end

  defp do_test_all(target_chunks, lookup_chunks) do
    chunks_count = Enum.count(target_chunks)
    data_dir_path = make_data_dir
    result =
      target_chunks
      |> Stream.with_index
      |> Flow.from_enumerable
      |> Flow.partition(stages: @stages_num)
      |> Flow.map(fn {target, index} ->
        IO.puts "---- #{index}..#{chunks_count - 1} ----"
        subdir_path = Path.join(data_dir_path, Integer.to_string(index))
        File.mkdir!(subdir_path)
        test_one(subdir_path, target, lookup_chunks)
      end)
      |> Enum.to_list
    p_a_list = Enum.filter_map(result,
                 fn {:ok, _, _} -> true; {:error, _} -> false end,
                 fn {:ok, _, [_, p, a]} -> {p, a} end)
    %{result: result, p_a_list: p_a_list, stats: %{chunks_count: chunks_count},
      profit: %{gt_threshold: profit(p_a_list),
                gt_0: profit(p_a_list, & &1 > 0),
                lt_0: profit(p_a_list, & &1 < 0),
                all_learned: profit(p_a_list, fn _ -> true end)},
      corr_filters: get_corr_filters_stats(result)}
    |> Map.update!(:stats, & Map.merge(&1, count_ev(p_a_list)))
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
    %{pos_count: pos_count,
      neg_count: neg_count,
      zero_count: zero_count,
      rate: safe_div(pos_count, (pos_count + neg_count))}
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

  defp get_corr_filters_stats(result) do
    result
    |> Enum.flat_map(& elem(&1, 1))
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      Map.update(acc, k, {0, 0}, fn {sum, n} -> {sum + v, n + 1} end)
    end)
    |> Enum.map(fn {k, {sum, n}} -> {k, Float.ceil(sum / n, 1)} end)
  end

  defp safe_div(a, b) do
    if b == 0 do
      :na
    else
      a / b
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
