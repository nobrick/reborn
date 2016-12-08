defmodule Machine.Corr do
  alias Experimental.Flow
  alias Ecto.Adapters.SQL
  alias Dirk.Repo

  @doc """
  Finds the chunks correlated with the `pattern` value list on the given `key`.

  Returns a stream of tuples in the format of `{chunk, correlation}`.

  ## Arguments
  
      `chunks`  - The base chunks to search in.
      `pattern` - The target value list to be patterned on. The correlation is
                  computed between the pattern list and the tail list of a
                  chunk. This also means that the size of the pattern list
                  should be `chuck_size - 1`.
      `key`     - The key on which the values are fetched in each delta map of
                  a chunk, to form a value list computing the correlation with
                  the given `pattern`.

  ## Examples

      iex> chunks = Machine.DataGen.fetch_chunks(100, 300000)
      iex> target_chunk = Machine.DataGen.fetch_chunks(0, 10) |> hd
      iex> pattern = target_chunk |> Enum.map(& &1.d_la) |> tl
      iex> stream = Machine.Corr.stream_corr_chunks(chunks, pattern, :d_la)
      iex> stream |> Stream.filter(& elem(&1, 1) >= 0.75) |> Enum.count

  """
  def stream_corr_chunks(chunks, pattern, key \\ :d_la) do
    chunks |> Stream.map(& map_corr_chunk(&1, pattern, key))
  end

  @corr_chunk_stages_num 4

  @doc """
  Finds the chunks correlated with the `pattern` value list in parallel on the
  given `key`.

  Similar to `stream_corr_chunks/3`. Returns a Flow struct.

  """
  def flow_corr_chunks(chunks, pattern, key \\ :d_la) do
    chunks
    |> Flow.from_enumerable
    |> Flow.partition(stages: @corr_chunk_stages_num)
    |> Flow.map(& map_corr_chunk(&1, pattern, key))
  end

  defp map_corr_chunk([_|chunk_tl] = chunk, pattern, key) do
    {chunk, Enum.map(chunk_tl, & Map.fetch!(&1, key)) |> compute_corr(pattern)}
  end

  @doc """
  Finds the chunks correlated with the `pattern` value list on the given `key`.

  Behind the scenes, the function uses `flow_corr_chunks/3`.  

  Returns a list of tuples in the format of `{chunk, correlation}`.

  """
  def find_corr_chunks(chunks, pattern, key \\ :d_la) do
    flow_corr_chunks(chunks, pattern, key) |> Enum.to_list
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
