defmodule Machine.Strategies do
  @moduledoc """
  Strategies for reveries.
  """

  import Machine.DataHelper, only: [ma_s: 1, ma_m: 1, ma_l: 1, la: 1,
                                    has_ma?: 1, bias: 2]

  def seq_r_fun(strategy, p, target_tl, %{r_fun_acc: prev_acc} = state) do
    strategy |> r_fun(p, target_tl, state) |> translate_r_fun(prev_acc)
  end

  def base_ma_pure_0(c1, c2) do
    la(c1) >= ma_s(c1) and
    ma_s(c1) >= ma_m(c1) and
    ma_s(c1) >= ma_s(c2) and # ema
    ma_m(c1) >= ma_m(c2) and # ema
    ma_l(c1) >= ma_l(c2) # ema
  end

  def base_ma_pure_0s(c1, c2) do
    la(c1) >= ma_s(c1) and
    ma_s(c1) >= ma_m(c1) and
    ma_m(c1) >= ma_l(c1) and
    ma_s(c1) >= ma_s(c2) and # ema
    ma_m(c1) >= ma_m(c2) and # ema
    ma_l(c1) >= ma_l(c2) # ema
  end

  def base_ma_pure_1(c1, c2) do
    la(c1) >= ma_s(c1) and
    ma_s(c1) >= ma_m(c1) and
    ma_m(c1) >= ma_l(c1) and
    la(c1) >= la(c2) # ema
  end

  defp translate_r_fun(instruction, prev_acc)
  when is_atom(instruction) or is_tuple(instruction) do
    [go: instruction, acc: prev_acc]
  end

  defp translate_r_fun(keywords, _), do: keywords

  defp r_fun(:gt_0, p, _, _) do
    cond do
      is_nil(p) ->
        :of_all
      p > 0 ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp r_fun(:gt_threshold, p, _, _) do
    cond do
      is_nil(p) ->
        :of_all
      p >= 0.0012 ->
        :bi_all
      p > 0 ->
        {:remain, :"p>0"}
      true ->
        :of_all
    end
  end

  defp r_fun(:gt_shift, p, _, _) do
    cond do
      is_nil(p) ->
        :of_all
      p >= 0.0012 ->
        :bi_all
      p > 0.0002 ->
        {:remain, :"p>0"}
      true ->
        :of_all
    end
  end

  defp r_fun(:ma_pure_0, p, target_tl, _) do
    [c1|[c2|_]] = target_tl
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      base_ma_pure_0(c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp r_fun(:ma_pure_0s, p, target_tl, _) do
    [c1|[c2|_]] = target_tl
    cond do
      is_nil(p) or not has_ma?([c1, c2]) ->
        :of_all
      base_ma_pure_0s(c1, c2) ->
        :bi_all
      true ->
        :of_all
    end
  end

  defp r_fun(:s_t0, p, target_tl, %{dd: dd, r_fun_acc: acc}) do
    [c1|[c2|[c3|_]]] = target_tl
    IO.inspect(c1)
    prev_risk_count = Map.get(acc, :risk_count, 0)
    has_ma = has_ma?([c1, c2, c3])
    {la_pulse, ma_pulse} =
      if has_ma do
        {dd - bias(la(c1), ma_s(c1)), dd - bias(ma_s(c1), ma_l(c1))}
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
end
