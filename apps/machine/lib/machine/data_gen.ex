defmodule Machine.DataGen do
  @moduledoc """
  Data generator for the machine adapters.
  """

  alias Dirk.Ticker.K15
  alias Dirk.Repo
  alias Utils.TimeDiff
  import Ecto.Query, only: [offset: 2, limit: 2]

  @chunk_size Application.get_env(:machine, :chunk_size)
  @chunk_step Application.get_env(:machine, :chunk_step)

  @doc """
  Fetches the data and converts it into a delta list.
  """
  def fetch_delta_list(offset, limit) do
    K15.distinct_on_time
    |> offset(^offset)
    |> limit(^(limit + 1))
    |> Repo.all
    |> into_delta_list
  end

  @doc """
  Fetches and chunks data.
  """
  def fetch_chunks(offset, limit, opts \\ []) do
    fetch_delta_list(offset, limit) |> chunk_data(opts)
  end

  @doc """
  Converts the data fetched from the database into a delta list in order to
  normalize the data.
  """
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

  def chunk_data(delta_list, opts \\ []) do
    count = opts[:chunk_size] || @chunk_size
    step = opts[:chunk_step] || @chunk_step
    delta_list
    |> Stream.chunk(count, step)
    |> Enum.filter(fn chunk ->
      time_pre = List.last(chunk).time
      time_post = hd(chunk).time
      TimeDiff.compare(time_pre, time_post, 15 * (count - 1)) == 0
      true
    end)
  end
end
