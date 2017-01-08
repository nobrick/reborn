alias Machine.Simulator.CSVParser
NimbleCSV.define(CSVParser, separator: "\t", escape: ~s("))

defmodule Machine.Simulator do
  @moduledoc """
  A module for simulating the backtest result.
  """

  import Utils.Number, only: [floor: 1]

  @compile {:inline, ma_s: 1, ma_m: 1, ma_l: 1, la: 1}
  @pft_threshold Application.get_env(:machine, :pft_threshold)
  @seq_names ~w(gt_threshold gt_0 exp_1 exp_2 exp_3 e4 la_gt_ma_s ma_e4 ma_e5
                ma_e45 ma_e45s ma_gt_0 ma_t0 ma_pure_0)a

  @doc """
  Simulates each sequence strategies and generate the pfts and instructions.
  """
  def test_sequence_pfts(result, target_chunks_count,
                          seq_names \\ @seq_names) do
    {seq_pfts, seq_lists} =
      seq_names
      |> Enum.map(fn n -> sequence_pft(result, & seq_r_fun(n, &1)) end)
      |> Enum.unzip
    seq_pfts =
      seq_names
      |> Enum.map(& :"seq_#{&1}")
      |> Enum.zip(Enum.map(seq_pfts, & {&1, target_chunks_count}))
    seq_lists = Enum.zip(seq_names, seq_lists)
    {seq_pfts, seq_lists}
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
  
  The first four columns are: :index, :decision, :holds, :ba, :d_la_initial.
  Among them, :decision, :holds and :ba are corresponding to the first method
  in the methods list
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
    |> Stream.map(fn {{decision, holds, ba, la, pft}, index} ->
      [index, inspect(decision), holds, ba, la, pft]
    end)
    |> (& Stream.concat([~w(n d ho ba d_la_initial #{method})], &1)).()
  end

  @doc """
  Calculates the decisions and pft expection for the `result` sequence returned
  by `Backtest.test_all/3` in *chronological* order.
  """
  def sequence_pft(result, r_fun, opts \\ []) do
    initial_ba = opts[:initial_ba] || 1.0
    initial_la = opts[:initial_ba] || 1.0
    slice_rate = opts[:slice_rate] || 0.1
    least_b_partial_scale = opts[:least_b_partial_scale] || 0.001
    slice = initial_ba * slice_rate
    least_b_partial = initial_ba * least_b_partial_scale
    calc_pft = fn holds, ba, la ->
      floor((ba + holds * la) / initial_ba - 1)
    end
    {seq_list, {holds, ba, la}} =
      Enum.map_reduce(result, {0, initial_ba, initial_la},
                      fn datum, {holds, ba, la} ->
        {_, _, a} = datum[:pred]
        next_la = la * (1 + a)
        remain = {holds, ba, next_la}
        decision = datum |> secure_datum |> r_fun.()
        log_state = fn decision ->
          d_la_initial = floor((la - initial_la) / initial_la)
          {decision, floor(holds), floor(ba), d_la_initial,
           calc_pft.(holds, ba, la)}
        end
        on = fn exp, value_fun ->
          if exp do
            {log_state.(decision), value_fun.()}
          else
            {log_state.({:remain, decision}), remain}
          end
        end
        case decision do
          :bi_slice ->
            on.(ba >= slice, fn ->
              {holds + slice / la, ba - slice, next_la}
            end)
          :of_slice ->
            h_slice = slice / la
            on.(holds >= h_slice, fn ->
              {holds - h_slice, ba + slice, next_la}
            end)
          :bi_all ->
            on.(ba > 0, fn ->
              {holds + ba / la, 0, next_la}
            end)
          :of_all ->
            on.(holds > 0, fn ->
              {0, ba + holds * la, next_la}
            end)
          {:bi_partial, b_partial_scale} ->
            b_partial = ba * b_partial_scale
            on.(b_partial >= least_b_partial, fn ->
              {holds + b_partial / la, ba - b_partial, next_la}
            end)
          {:of_partial, h_partial_scale} ->
            h_partial = holds * h_partial_scale
            on.(h_partial * la >= least_b_partial, fn ->
              {holds - h_partial, ba + h_partial * la, next_la}
            end)
          {:remain, _} ->
            {log_state.(decision), remain}
        end
      end)
    {calc_pft.(holds, ba, la), seq_list}
  end

  defp secure_datum(datum) do
    {_, p, _} = datum[:pred]
    [_|prev_chunk] = datum[:chunk]
    datum
    |> put_in([:p], p)
    |> put_in([:prev_chunk], prev_chunk)
    |> Keyword.drop([:pred, :chunk])
  end

  ## Sequence functions

  defp seq_r_fun(:gt_threshold, datum) do
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

  defp seq_r_fun(:gt_0, datum) do
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

  defp seq_r_fun(:exp_1, datum) do
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

  defp seq_r_fun(:exp_2, datum) do
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

  defp seq_r_fun(:exp_3, datum) do
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

  defp seq_r_fun(:e4, datum) do
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

  defp seq_r_fun(:la_gt_ma_s, datum) do
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

  defp seq_r_fun(:ma_pure_0, datum) do
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

  defp seq_r_fun(:ma_e4, datum) do
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

  defp seq_r_fun(:ma_e5, datum) do
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

  defp seq_r_fun(:ma_e45, datum) do
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

  defp seq_r_fun(:ma_e45s, datum) do
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

  defp seq_r_fun(:ma_gt_0, datum) do
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

  defp seq_r_fun(:ma_t0, datum) do
    p = datum[:p]
    [c1|[c2|[c3|_]]] = datum[:prev_chunk]
    cond do
      is_nil(p) or not has_ma?([c1, c2, c3]) ->
        :of_all
      base_e4(p, c1, c2) ->
        :bi_all
      base_la_gt_ma_s(p, c1, c2) ->
        :bi_all
      p > 0 and ma_s(c1) >= ma_s(c2) and ma_s(c2) >= ma_s(c3) ->
        :bi_all
      base_ma_pure_0(c1, c2) ->
        :bi_all
      true ->
        :of_all
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
    ma_s(c1) >= ma_m(c1) and
    ma_s(c1) >= ma_s(c2) and
    ma_m(c1) >= ma_m(c2) and
    ma_l(c1) >= ma_l(c2) and
    la(c1) >= ma_s(c1)
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
