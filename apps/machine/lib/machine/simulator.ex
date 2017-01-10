alias Machine.Simulator.CSVParser
NimbleCSV.define(CSVParser, separator: "\t", escape: ~s("))

defmodule Machine.Simulator do
  @moduledoc """
  A module for simulating the backtest result.
  """

  import Utils.Number, only: [floor: 1]

  @compile {:inline, init_seq_pft_state: 0, ma_s: 1, ma_m: 1, ma_l: 1, la: 1}
  @pft_threshold Application.get_env(:machine, :pft_threshold)
  @seq_names ~w(gt_threshold gt_0 exp_1 exp_2 exp_3 e4 la_gt_ma_s ma_e4 ma_e5
                ma_e45 ma_e45s ma_gt_0 ma_pure_0 ma_pure_0s ma_pure_1 s_t0)a

  @doc """
  Simulates each sequence strategies and generate the pfts and instructions.
  """
  def test_sequence_pfts(result, seq_names \\ @seq_names) do
    {seq_info, seq_lists} =
      seq_names
      |> Enum.map(fn n -> sequence_pft(result, & seq_r_fun(n, &1, &2)) end)
      |> Enum.unzip
    seq_info = seq_names |> Enum.map(& :"seq_#{&1}") |> Enum.zip(seq_info)
    seq_lists = Enum.zip(seq_names, seq_lists)
    {seq_info, seq_lists}
  end

  @doc """
  Writes seq_list into a CSV file.
  """
  def put_csv(seq_list, method, opts \\ []) when is_atom(method) do
    path = opts[:path] || "#{method}.txt"
    seq_list
    |> put_seq_to_stream(method)
    |> CSVParser.dump_to_iodata
    |> (& File.write!(path, &1, [:write])).()
  end

  @doc """
  Writes all seq_lists into a single CSV file.
  
  The first four columns are: :index, :instruction, :holds, :ba, :d_la_initial.
  Among them, :instruction, :holds and :ba are corresponding to the first
  method in the methods list
  """
  def put_summary_csv(seq_lists, opts \\ []) do
    path = opts[:path] || "summary.txt"
    [first_method|rest_methods] = opts[:methods] || Keyword.keys(seq_lists)
    stream = put_seq_to_stream(seq_lists[first_method], first_method)
    rest_streams =
      Enum.map(rest_methods, fn method ->
        seq_lists[method]
        |> Stream.map(fn {_, _, _, _, pft} -> [pft] end)
        |> (& Stream.concat([~w(#{method})], &1)).()
      end)
    [stream|rest_streams]
    |> Stream.zip
    |> Stream.map(fn tuple -> tuple |> Tuple.to_list |> List.flatten end)
    |> CSVParser.dump_to_iodata
    |> (& File.write!(path, &1, [:write])).()
  end

  defp put_seq_to_stream(seq_list, method) when is_atom(method) do
    seq_list
    |> Stream.with_index(1)
    |> Stream.map(fn {{instruction, holds, ba, la, pft}, index} ->
      [index, inspect(instruction), holds, ba, la, pft]
    end)
    |> (& Stream.concat([~w(n d ho ba d_la_initial #{method})], &1)).()
  end

  @doc """
  Calculates the decisions and accumulated info for the `result` sequence
  returned by `Backtest.test_all/3` in *chronological* order.
  """
  def sequence_pft(result, r_fun) do
    {seq_list, {_, _, _, %{pft: pft, mdd: mdd, max_nav: max_nav,
                           min_nav: min_nav}}} =
      Enum.map_reduce(result, init_seq_pft_state(), fn datum, state ->
        seq_pft_map_reducer(datum, state, r_fun)
      end)
    {{floor(pft), mdd: floor(mdd), max_pft: floor(max_nav - 1),
      min_pft: floor(min_nav - 1)}, seq_list}
  end

  defp init_seq_pft_state do
    {0, 1.0, 1.0, %{nav: 1.0, pft: 0, max_nav: 1.0, min_nav: 1.0, dd: 0,
                    mdd: 0, r_fun_acc: %{}}}
  end

  defp next_seq_pft_state({next_holds, next_ba}, next_r_fun_acc, datum,
       {_, _, curr_la, %{max_nav: curr_max_nav, min_nav: curr_min_nav,
       mdd: curr_mdd}} = _state) do
    {_, _, a} = datum[:pred]
    next_la = curr_la * (1 + a)
    next_nav = next_ba + next_holds * next_la
    next_pft = next_nav - 1.0
    next_max_nav = max(curr_max_nav, next_nav)
    next_min_nav = min(curr_min_nav, next_nav)
    next_dd = (curr_max_nav - next_nav) / curr_max_nav
    next_mdd = max(curr_mdd, next_dd)
    next_derived = %{nav: next_nav, pft: next_pft, max_nav: next_max_nav,
                     min_nav: next_min_nav, dd: next_dd, mdd: next_mdd,
                     r_fun_acc: next_r_fun_acc}
    {next_holds, next_ba, next_la, next_derived}
  end

  defp next_r_fun_acc(decision, condition,
                      {_, _, _, %{r_fun_acc: curr_acc}}) do
    proposed_next_acc = Keyword.fetch!(decision, :acc)
    cond do
      condition ->
        proposed_next_acc
      Keyword.get(decision, :use_next_acc_on_remain, false) ->
        proposed_next_acc
      true ->
        curr_acc
    end
  end

  defp seq_pft_mapper(instruction, {holds, ba, la, %{pft: pft}} = _state) do
    {instruction, floor(holds), floor(ba), floor(la - 1), floor(pft)}
  end

  defp seq_pft_map_reducer(datum, {holds, ba, _, _} = state, r_fun) do
    decision = datum |> secure_datum |> r_fun.(state) |> translate_r_fun(state)
    instruction = Keyword.fetch!(decision, :go)
    {condition, value_fun} = decode_instruction(instruction, state)
    r_fun_acc = next_r_fun_acc(decision, condition, state)
    if condition do
      {seq_pft_mapper(instruction, state),
       next_seq_pft_state(value_fun.(), r_fun_acc, datum, state)}
    else
      {instruction |> wrap_remain |> seq_pft_mapper(state),
       next_seq_pft_state({holds, ba}, r_fun_acc, datum, state)}
    end
  end

  defp wrap_remain({:remain, _} = instruction), do: instruction
  defp wrap_remain(instruction), do: {:remain, instruction}

  defp secure_datum(datum) do
    {_, p, _} = datum[:pred]
    [_|prev_chunk] = datum[:chunk]
    datum
    |> put_in([:p], p)
    |> put_in([:prev_chunk], prev_chunk)
    |> Keyword.drop([:pred, :chunk])
  end

  defp decode_instruction(instruction, {holds, ba, la, _derived} = _state) do
    slice = 0.1
    least_b_partial = 0.001
    case instruction do
      :bi_slice ->
        {ba >= slice, fn ->
          {holds + slice / la, ba - slice}
        end}
      :of_slice ->
        h_slice = slice / la
        {holds >= h_slice, fn ->
          {holds - h_slice, ba + slice}
        end}
      :bi_all ->
        {ba > 0, fn ->
          {holds + ba / la, 0}
        end}
      :of_all ->
        {holds > 0, fn ->
          {0, ba + holds * la}
        end}
      {:bi_partial, b_partial_scale} ->
        b_partial = ba * b_partial_scale
        {b_partial >= least_b_partial, fn ->
          {holds + b_partial / la, ba - b_partial}
        end}
      {:of_partial, h_partial_scale} ->
        h_partial = holds * h_partial_scale
        {h_partial * la >= least_b_partial, fn ->
          {holds - h_partial, ba + h_partial * la}
        end}
      {:remain, _} ->
        {false, nil}
    end
  end

  defp translate_r_fun(instruction, {_, _, _, %{r_fun_acc: r_fun_acc}})
  when is_atom(instruction) or is_tuple(instruction) do
    [go: instruction, acc: r_fun_acc]
  end

  defp translate_r_fun(keywords, _), do: keywords

  ## Sequence functions

  defp seq_r_fun(:gt_threshold, datum, _) do
    p = datum[:p]
    cond do
      is_nil(p) ->
        {:of_partial, 0.8}
      p >= @pft_threshold ->
        :bi_all
      p > 0 ->
        {:remain, :"p>0"}
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:gt_0, datum, _) do
    p = datum[:p]
    cond do
      is_nil(p) ->
        {:of_partial, 0.8}
      p > 0 ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:exp_1, datum, _) do
    p = datum[:p]
    cond do
      is_nil(p) ->
        {:of_partial, 0.8}
      p > 0 ->
        {:bi_partial, 0.4}
      true ->
        {:of_partial, 0.6}
    end
  end

  defp seq_r_fun(:exp_2, datum, _) do
    p = datum[:p]
    cond do
      is_nil(p) ->
        {:of_partial, 0.8}
      p > 0 ->
        {:bi_partial, 0.2}
      true ->
        {:of_partial, 0.8}
    end
  end

  defp seq_r_fun(:exp_3, datum, _) do
    p = datum[:p]
    cond do
      is_nil(p) ->
        {:of_partial, 0.8}
      p > 0 ->
        :bi_slice
      true ->
        {:of_partial, 0.8}
    end
  end

  defp seq_r_fun(:e4, datum, _) do
    p = datum[:p]
    [c1|[c2|_]] = datum[:prev_chunk]
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      base_e4(p, c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:la_gt_ma_s, datum, _) do
    p = datum[:p]
    [c1|[c2|_]] = datum[:prev_chunk]
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      base_la_gt_ma_s(p, c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:ma_pure_0, datum, _) do
    p = datum[:p]
    [c1|[c2|_]] = datum[:prev_chunk]
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      base_ma_pure_0(c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:ma_pure_0s, datum, _) do
    p = datum[:p]
    [c1|[c2|_]] = datum[:prev_chunk]
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      base_ma_pure_0s(c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:ma_pure_1, datum, _) do
    p = datum[:p]
    [c1|[c2|_]] = datum[:prev_chunk]
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      base_ma_pure_1(c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:ma_e4, datum, _) do
    p = datum[:p]
    [c1|[c2|_]] = datum[:prev_chunk]
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      base_e4(p, c1, c2) ->
        :bi_all
      base_ma_pure_0(c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:ma_e5, datum, _) do
    p = datum[:p]
    [c1|[c2|_]] = datum[:prev_chunk]
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      base_la_gt_ma_s(p, c1, c2) ->
        :bi_all
      base_ma_pure_0(c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:ma_e45, datum, _) do
    p = datum[:p]
    [c1|[c2|_]] = datum[:prev_chunk]
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      base_e4(p, c1, c2) ->
        :bi_all
      base_la_gt_ma_s(p, c1, c2) ->
        :bi_all
      base_ma_pure_0(c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:ma_e45s, datum, _) do
    p = datum[:p]
    [c1|[c2|_]] = datum[:prev_chunk]
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      base_e4(p, c1, c2) ->
        :bi_all
      base_la_gt_ma_s(p, c1, c2) and ma_s(c1) >= ma_m(c1) ->
        :bi_all
      base_ma_pure_0(c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:ma_gt_0, datum, _) do
    p = datum[:p]
    [c1|[c2|_]] = datum[:prev_chunk]
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      p > 0 ->
        :bi_all
      base_ma_pure_0(c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_r_fun(:s_t0, datum,
                 {_holds, _ba, _la, %{dd: dd, r_fun_acc: acc}}) do
    p = datum[:p]
    [c1|[c2|[c3|_]]] = datum[:prev_chunk]
    prev_risk_count = Map.get(acc, :risk_count, 0)
    has_ma = has_ma?([c1, c2, c3])
    {la_pulse, ma_pulse} =
      if has_ma do
        {(ma_s(c1) - la(c1)) / ma_s(c1) + 1.5 * dd,
         (ma_l(c1) - ma_s(c1)) / ma_l(c1) + 1.5 * dd}
      else
        {-1, -1}
      end
    risk_count =
      cond do
        ma_pulse < 0 or la_pulse < 0 ->
          1
        prev_risk_count <= 0 and dd <= 0.08 ->
          0
        prev_risk_count <= 0 ->
          1
        dd <= 0.01 ->
          0
        true ->
          1
      end
    go = fn instruction ->
      [go: instruction, acc: put_in(acc[:risk_count], risk_count)]
    end

    cond do
      is_nil(p) or not has_ma ->
        go.(:of_all)
      base_ma_pure_0(c1, c2) ->
        go.(:bi_all)
      base_ma_pure_1(c1, c2) ->
        go.(:bi_all)
      p > 0 and risk_count <= 0 ->
        go.(:bi_all)
      true ->
        go.(:of_all)
    end
  end

  ## Base functions

  defp base_la_gt_ma_s(p, c1, _c2) do
    p > 0 and la(c1) >= ma_s(c1)
  end

  defp base_e4(p, c1, c2) do
    p > 0 and ma_s(c1) >= ma_m(c1) and
              ma_s(c1) >= ma_s(c2) and
              ma_m(c1) >= ma_m(c2)
  end

  defp base_ma_pure_0(c1, c2) do
    la(c1) >= ma_s(c1) and
    ma_s(c1) >= ma_m(c1) and
    ma_s(c1) >= ma_s(c2) and # ema
    ma_m(c1) >= ma_m(c2) and # ema
    ma_l(c1) >= ma_l(c2) # ema
  end

  defp base_ma_pure_0s(c1, c2) do
    la(c1) >= ma_s(c1) and
    ma_s(c1) >= ma_m(c1) and
    ma_m(c1) >= ma_l(c1) and
    ma_s(c1) >= ma_s(c2) and # ema
    ma_m(c1) >= ma_m(c2) and # ema
    ma_l(c1) >= ma_l(c2) # ema
  end

  defp base_ma_pure_1(c1, c2) do
    la(c1) >= ma_s(c1) and
    ma_s(c1) >= ma_m(c1) and
    ma_m(c1) >= ma_l(c1) and
    la(c1) >= la(c2) # ema
  end

  ## Helpers

  defp ma_s(chunk_datum), do: chunk_datum[:t][:sma_s]
  defp ma_m(chunk_datum), do: chunk_datum[:t][:sma_m]
  defp ma_l(chunk_datum), do: chunk_datum[:t][:sma_l]
  defp la(chunk_datum), do: chunk_datum[:t][:la]

  defp has_ma?(chunk_datums) when is_list(chunk_datums) do
    Enum.all?(chunk_datums, &has_ma?/1)
  end

  defp has_ma?(chunk_datum) do
    ma_s(chunk_datum) && ma_m(chunk_datum) && ma_l(chunk_datum)
  end
end
