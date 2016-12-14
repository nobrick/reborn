defmodule Machine.DataGen do
  @moduledoc """
  Data generator for the machine adapters.
  """

  alias Dirk.Ticker.K15
  alias Dirk.Repo
  alias Utils.TimeDiff
  import Ecto.Query, only: [offset: 2, limit: 2, where: 3]

  @compile {:inline, chunk_elems_in_seq?: 2}

  @chunk_size Application.get_env(:machine, :chunk_size)
  @chunk_step Application.get_env(:machine, :chunk_step)

  @doc """
  Fetches the data.

  Behind the scenes, this method queries the database with `limit + 1` since
  the associated delta list count is less than ticker count by 1.
  """
  def fetch_data(offset, limit) do
    K15.distinct_on_time
    |> offset(^offset)
    |> limit(^(limit + 1))
    |> Repo.all
  end

  @doc """
  Fetches the data by the given time.

  Examples:

      iex> start_time = {{2016, 12, 08}, {17, 0, 0}}
      iex> end_time = {{2016, 12, 13}, {11, 45, 0}}
      iex> Machine.DataGen.fetch_data_by_time(start_time, end_time)

  """
  def fetch_data_by_time(start_time, end_time)
      when is_tuple(start_time) and is_tuple(end_time) do
    import Ecto.DateTime, only: [from_erl: 1]
    fetch_data_by_time(from_erl(start_time), from_erl(end_time))
  end

  def fetch_data_by_time(start_time, end_time) do
    K15.distinct_on_time
    |> where([k],
         k.time <= ^end_time and
         k.time >= datetime_add(^start_time, -15, "minute"))
    |> Repo.all
  end

  @doc """
  Fetches and chunks data.
  """
  def fetch_chunks(offset, limit, opts \\ []) do
    offset |> fetch_data(limit) |> into_delta_list |> chunk_data(opts)
  end

  @doc """
  Fetches and chunks data by the given time.
  """
  def fetch_chunks_by_time(start_time, end_time, opts \\ []) do
    start_time
    |> fetch_data_by_time(end_time)
    |> into_delta_list
    |> chunk_data(opts)
  end

  @doc """
  Converts the data fetched from the database using `fetch_data/2` or
  `fetch_data_by_time/2` into a delta list in order to normalize the data.
  """
  # TODO: Checks time consitency.
  def into_delta_list(data) do
    build_delta_list(data, []) |> :lists.reverse
  end

  defp build_delta_list([], acc),  do: acc
  defp build_delta_list([_], acc), do: acc

  defp build_delta_list([post|[pre|_] = tail], acc) do
    build_delta_list(tail, [build_delta(post, pre)|acc])
  end

  defp build_delta(post, pre) do
    %{d_op: (post.op - pre.op) / pre.op,
      d_la: (post.la - pre.la) / pre.la,
      d_hi: (post.hi - pre.hi) / pre.hi,
      d_lo: (post.lo - pre.lo) / pre.lo,
      d_vo: (post.vo - pre.vo) / (post.vo + pre.vo + 1),
      id: post.id,
      time: post.time}
  end

  @doc """
  Converts the given delta list into a list of chunks.
  """
  def chunk_data(delta_list, opts \\ []) do
    count = opts[:chunk_size] || @chunk_size
    step = opts[:chunk_step] || @chunk_step
    delta_list
    |> Stream.chunk(count, step)
    |> Enum.filter(& chunk_elems_in_seq?(&1, count))
  end

  defp chunk_elems_in_seq?(chunk, chunk_size) do
    time_pre = List.last(chunk).time
    time_post = hd(chunk).time
    TimeDiff.compare(time_pre, time_post, 15 * (chunk_size - 1)) == 0
  end
end
