defmodule Machine.Simulator do
  @moduledoc """
  A module for simulating the backtest result.
  """

  import Utils.Number, only: [floor: 1]

  @pft_threshold Application.get_env(:machine, :pft_threshold)
  @seq_names ~w(gt_threshold gt_0 exp_1 exp_2 exp_3)a

  @doc """
  Simulates each sequence strategies and generate the pfts and instructions.
  """
  def test_sequence_pfts(result, target_chunks_count,
                          seq_names \\ @seq_names) do
    {seq_pfts, seq_lists} =
      seq_names
      |> Enum.map(fn atom ->
        sequence_pft(result, p_fun: & seq_p_fun(atom, &1))
      end)
      |> Enum.unzip
    seq_pfts =
      seq_names
      |> Enum.map(& :"seq_#{&1}")
      |> Enum.zip(Enum.map(seq_pfts, & {&1, target_chunks_count}))
    seq_lists = Enum.zip(seq_names, seq_lists)
    {seq_pfts, seq_lists}
  end

  @doc """
  Calculates the decisions and pft expection for the `result` sequence returned
  by `Backtest.test_all/3` in *chronological* order.
  """
  def sequence_pft(result, opts \\ []) do
    p_fun = opts[:p_fun] || & seq_p_fun(:gt_0, &1)
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
                  fn {_, _, {_, p, a}, _}, {holds, ba, la} ->
        next_la = la * (1 + a)
        remain = {holds, ba, next_la}
        decision = p_fun.(p)
        log_state = fn decision ->
          {decision, floor(holds), floor(ba), floor(la),
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

  defp seq_p_fun(:gt_threshold, p) do
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

  defp seq_p_fun(:gt_0, p) do
    cond do
      is_nil(p) ->
        {:of_partial, 0.8}
      p > 0 ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp seq_p_fun(:exp_1, p) do
    cond do
      is_nil(p) ->
        {:of_partial, 0.8}
      p > 0 ->
        {:bi_partial, 0.4}
      true ->
        {:of_partial, 0.6}
    end
  end

  defp seq_p_fun(:exp_2, p) do
    cond do
      is_nil(p) ->
        {:of_partial, 0.8}
      p > 0 ->
        {:bi_partial, 0.2}
      true ->
        {:of_partial, 0.8}
    end
  end

  defp seq_p_fun(:exp_3, p) do
    cond do
      is_nil(p) ->
        {:of_partial, 0.8}
      p > 0 ->
        :bi_slice
      true ->
        {:of_partial, 0.8}
    end
  end
end
