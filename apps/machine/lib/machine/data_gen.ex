defmodule Machine.DataGen do
  @moduledoc """
  Data generator for the machine adapters.
  """

  alias Dirk.Ticker.K15
  alias Dirk.Repo
  import Ecto.Query, only: [offset: 2, limit: 2, where: 3]
  import Machine.DataHelper, only: [bias: 2, chunk_elems_in_seq?: 2,
                                    chunk_size: 1]

  @chunk_step Application.get_env(:machine, :chunk_step)

  @doc """
  Fetches the data.

  Behind the scenes, this method queries the database with `limit + 1` since
  the associated delta list count is less than ticker count by 1.
  """
  def fetch_data(offset, limit, opts \\ []) do
    K15.order_by_time_desc
    |> offset(^offset)
    |> limit(^(limit + 1))
    |> Repo.all(opts)
  end

  def fetch_latest do
    [latest] = K15.order_by_time_desc |> limit(1) |> Repo.all(log: false)
    latest
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
    K15.order_by_time_desc
    |> where([k],
         k.time <= ^end_time and
         k.time >= datetime_add(^start_time, -15, "minute"))
    |> Repo.all
  end

  @doc """
  Fetches and chunks data.
  """
  def fetch_chunks(offset, limit, opts \\ []) do
    offset |> fetch_data(limit) |> build_chunks(opts)
  end

  @doc """
  Builds chunks from fetched data.
  """
  def build_chunks(data, opts \\ []) do
    data
    |> pre_process(opts[:methods])
    |> into_delta_list
    |> chunk_data(opts)
  end

  @doc """
  Fetches and chunks data by the given time.
  """
  def fetch_chunks_by_time(start_time, end_time, opts \\ []) do
    start_time
    |> fetch_data_by_time(end_time)
    |> pre_process(opts[:methods])
    |> into_delta_list
    |> chunk_data(opts)
  end

  @doc """
  Pre-processes the data with the given methods.
  """
  def pre_process(data, methods \\ nil)
      when is_list(methods) or is_nil(methods) do
    methods = methods || [{:sma, key: :sma_xs, period: 3, keep_all: true},
                          {:sma, key: :sma_s, period: 7, keep_all: true},
                          {:sma, key: :sma_m, period: 14, keep_all: true},
                          {:sma, key: :sma_l, period: 28, keep_all: true},
                          {:sma, key: :sma_xl, period: 56}]
    Enum.reduce(methods, Enum.reverse(data), fn method, payload ->
      Machine.Indicators.run(method, payload)
    end)
    |> Enum.reverse
  end

  @doc """
  Converts the data fetched from the database using `fetch_data/2` or
  `fetch_data_by_time/2` into a delta list in order to normalize the data.
  """
  # TODO: Check time consitency.
  def into_delta_list(data) do
    build_delta_list(data, []) |> :lists.reverse
  end

  defp build_delta_list([], acc),  do: acc
  defp build_delta_list([_], acc), do: acc

  defp build_delta_list([post|[pre|_] = tail], acc) do
    build_delta_list(tail, [build_delta(post, pre)|acc])
  end

  defp build_delta(%K15{} = post, %K15{} = pre) do
    build_delta(Map.from_struct(post), Map.from_struct(pre))
  end

  defp build_delta(post, pre) do
    %{d_op: bias(post.op, pre.op),
      d_la: bias(post.la, pre.la),
      d_hi: bias(post.hi, pre.hi),
      d_lo: bias(post.lo, pre.lo),
      d_vo: (post.vo - pre.vo) / (post.vo + pre.vo + 1),
      bias_hi_s: na_or_value(post, [:sma_s], fn ->
        bias(post.hi, post.sma_s)
      end),
      bias_lo_s: na_or_value(post, [:sma_s], fn ->
        bias(post.lo, post.sma_s)
      end),
      bias_s_m: na_or_value(post, [:sma_s, :sma_m], fn ->
        bias(post.sma_s, post.sma_m)
      end),
      bias_m_l: na_or_value(post, [:sma_m, :sma_l], fn ->
        bias(post.sma_m, post.sma_l)
      end),
      bias_l_xl: na_or_value(post, [:sma_l, :sma_xl], fn ->
        bias(post.sma_l, post.sma_xl)
      end),
      bias_la_s: na_or_value(post, [:sma_s], fn ->
        bias(post.la, post.sma_s)
      end),
      bias_la_m: na_or_value(post, [:sma_m], fn ->
        bias(post.la, post.sma_m)
      end),
      id: post.id, time: post.time,
      t: Map.delete(post, :__meta__)}
  end

  defp na_or_value(datum, keys, fun) do
    if keys |> Enum.all?(& datum[&1]) do
      fun.()
    else
      :na
    end
  end

  @doc """
  Converts the given delta list into a list of chunks.
  """
  def chunk_data(delta_list, opts \\ []) do
    count = chunk_size(opts)
    step = opts[:chunk_step] || @chunk_step
    delta_list
    |> Stream.chunk(count, step)
    |> Enum.filter(& chunk_elems_in_seq?(&1, count))
  end
end
