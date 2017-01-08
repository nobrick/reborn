defmodule Machine.Indicators.SMA do
  @moduledoc """
  Responsible for calculating simple moving average.
  """

  alias Utils.TimeDiff

  @precision 3

  def run(payload, opts \\ []) do
    if Keyword.get(opts, :validation, true) do
      validate_sorted!(payload)
    end
    period = opts[:period]
    key = opts[:key] || :"sma#{period}"

    first_chunk = Enum.take(payload, period)
    sum = first_chunk |> Enum.map(& &1.la) |> Enum.sum
    avg = round_float(sum / period)
    first_datum = first_chunk |> List.last |> Map.put(key, avg)

    stream =
      payload
      |> Stream.drop(period)
      |> Stream.zip(payload)
      |> Stream.transform(sum, fn {datum, datum_behind}, sum ->
        new_sum = sum - datum_behind.la + datum.la
        new_avg = round_float(new_sum / period)
        {[Map.put(datum, key, new_avg)], new_sum}
      end)
      |> (& Stream.concat([first_datum], &1)).()

    if Keyword.get(opts, :keep_all, false) do
      payload
      |> Enum.take(period - 1)
      |> Stream.concat(stream)
    else
      stream
    end
  end

  defp round_float(value, precision \\ @precision) do
    Float.round(value, precision)
  end

  defp validate_sorted!(payload) do
    [p1, p2] = Enum.take(payload, 2)
    if TimeDiff.compare(p1.time, p2.time, nil, :seconds) >= 0 do
      raise ArgumentError, message: "data should be in ascending-time order"
    end
  end
end

defmodule SMA1 do
  @moduledoc """
  Cross validating the correctness of SMA algorithm.
  """

  @doc """
  Calculates SMA from given list.
  """
  def sma(_data, period) when period < 2, do: :error

  def sma(data, period) when is_list(data) and is_integer(period) do
    case (Enum.count(data) < period) do
      true ->
        []
      false ->
        {init_block, rest} = Enum.split(data, period)
        init_block_sum = Enum.sum(init_block)
        init_avg = init_block_sum / period
        _sma(init_block, [], rest, init_block_sum, period, [init_avg])
    end
  end

  def sma(_, _), do: :error

  defp _sma(_, _, [], _, _, averages) do
    Enum.reverse(averages)
  end

  defp _sma([], current_sample, rest, prev_sum, period, averages) do
    _sma(Enum.reverse(current_sample), [], rest, prev_sum, period, averages)
  end

  defp _sma([h_f | f], current_sample, [h_r | r], prev_sum, period, averages) do
    sum = prev_sum - h_f + h_r
    avg = sum / period
    _sma(f, [h_r] ++ current_sample, r, sum, period, [avg] ++ averages)
  end
end
