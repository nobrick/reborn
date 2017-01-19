defmodule Machine.Corr do
  alias Experimental.Flow
  alias Ecto.Adapters.SQL
  alias Dirk.Repo

  def stream_corr_chunks(chunks, pattern) do
    Stream.map(chunks, & map_corr_chunk(&1, pattern))
  end

  @corr_chunk_stages_num 4

  def flow_corr_chunks(chunks, pattern) do
    chunks
    |> Flow.from_enumerable
    |> Flow.partition(stages: @corr_chunk_stages_num)
    |> Flow.map(& map_corr_chunk(&1, pattern))
  end

  defp map_corr_chunk(chunk, pattern) do
    {chunk, compute_corr(get_pattern(chunk), pattern)}
  end

  def find_corr_chunks(chunks, target_tl) do
    chunks |> flow_corr_chunks(get_pattern(target_tl)) |> Enum.to_list
  end

  defp get_pattern(target_tl) do
    # Enum.map(target_tl, & &1.d_la)
    [c1|[c2|[c3|_]]] = target_tl
    [c1.bias_la_s, c1.bias_s_m, c1.bias_m_l, c1.d_la, c2.d_la, c3.d_la]
  end

  @doc """
  Filters the corr chunks enumerable with the given `filters` list.

  ## Examples

      iex> Machine.Corr.stream_corr_chunks(chunks, pattern)
      ...> |> Machine.Corr.filter_corr_chunks([{0.90, 20}, {0.85, 30}])

  """
  def filter_corr_chunks(corr_chunks, filters, logs \\ [])
  def filter_corr_chunks(_corr_chunks, [], logs), do: {:error, logs}
  def filter_corr_chunks(corr_chunks, [{min_corr, min_count}|tail], logs) do
    filtered = Enum.filter(corr_chunks, & elem(&1, 1) >= min_corr)
    count = Enum.count(filtered)
    logs = [{min_corr, count}|logs]
    if count >= min_count do
      {:ok, logs, filtered}
    else
      filter_corr_chunks(corr_chunks, tail, logs)
    end
  end

  @doc """
  Computes the correlation of two equal-size finite enumerables.

  ## Examples

      iex> Machine.Corr.compute_corr([1, 2, 3], [4, 5, 7])

  """
  def compute_corr(enum1, enum2), do: Statistics.correlation(enum1, enum2)

  @doc """
  Computes the correlation of two equal-size finite enumerables.

  Deprecated. Use `compute_corr/2` instead.
  """
  def compute_corr2(enumerable1, enumerable2)
      when length(enumerable1) == length(enumerable2) do
    input =
      enumerable1
      |> Stream.zip(enumerable2)
      |> Enum.map_join(", ", fn {a, b} -> "(#{a}, #{b})" end)
    sql = "SELECT corr(c1, c2) FROM (VALUES #{input}) AS t (c1, c2)"
    %{rows: [[value]]} = SQL.query!(Repo, sql, [], log: false)
    value
  end
end
