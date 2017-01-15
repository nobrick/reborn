defmodule Machine.DataHelper do
  @moduledoc """
  Data helper.
  """

  alias Utils.TimeDiff

  @compile {:inline, bias: 2, ma_s: 1, ma_m: 1, ma_l: 1, la: 1,
            chunk_elems_in_seq?: 2, chunk_size: 1}
  @chunk_size Application.get_env(:machine, :chunk_size)

  def ma_s(chunk_datum), do: chunk_datum[:t][:sma_s]
  def ma_m(chunk_datum), do: chunk_datum[:t][:sma_m]
  def ma_l(chunk_datum), do: chunk_datum[:t][:sma_l]
  def la(chunk_datum), do: chunk_datum[:t][:la]

  def has_ma?(chunk_datums) when is_list(chunk_datums) do
    Enum.all?(chunk_datums, &has_ma?/1)
  end

  def has_ma?(chunk_datum) do
    ma_s(chunk_datum) && ma_m(chunk_datum) && ma_l(chunk_datum)
  end

  def bias(a, b), do: a / b - 1.0

  def chunk_elems_in_seq?(chunk, chunk_size) do
    time_pre = List.last(chunk).time
    time_post = hd(chunk).time
    TimeDiff.compare(time_pre, time_post, 15 * (chunk_size - 1)) == 0
  end

  def chunk_size(opts) do
    opts[:chunk_size] || @chunk_size
  end
end
