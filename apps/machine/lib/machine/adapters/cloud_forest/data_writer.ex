defmodule Machine.Adapters.CloudForest.DataWriter do
  @moduledoc """
  Data writer for CloudForest.
  """

  defmodule State do
    @chunk_size   Application.get_env(:machine, :chunk_size)
    @feature_keys Application.get_env(:machine, :feature_keys)

    defstruct chunk_size: @chunk_size,
      feature_keys: @feature_keys,
      header_string: nil
  end

  use GenServer

  @pattern_key Application.get_env(:machine, :pattern_key)
  @server __MODULE__

  ## API

  @doc """
  Starts the data writer server.
  """
  def start_link(args \\ %{}, opts \\ []) when is_map(args) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Saves the data to the given file `path` for training or testing.

  ## Arguments

      `server` - The DataGen process.
      `path` - The samples path for saving.
      `chunks` - An enumerable of chunks.
  """
  def save_data(server \\ @server, path, chunks, opts \\ []) do
    GenServer.call(server, {:save_data, path, chunks, opts})
  end

  def save_test(server \\ @server, path, target_tl, opts \\ []) do
    GenServer.call(server, {:save_test, path, target_tl, opts})
  end

  ## Callbacks

  def init(args) do
    {:ok, Map.merge(%State{}, args) |> update_header}
  end

  defp update_header(%{chunk_size: chunk_size,
                     feature_keys: feature_keys} = state) do
    features =
      [".", "N:#{@pattern_key}0"] ++
      for index <- 1..(chunk_size - 1), key <- feature_keys do
        "N:#{key}#{index}"
      end
    %{state|header_string: Enum.join(features, "\t")}
  end

  def handle_call({:save_test, path, target_tl, opts}, _from,
      %{chunk_size: chunk_size} = state)
      when length(target_tl) + 1 == chunk_size do
    id = opts[:id] || -1
    value = opts[:actual] || -1.0
    chunks = [[%{:id => id, @pattern_key => value}|target_tl]]
    do_save_data(path, chunks, state)
    {:reply, :ok, state}
  end

  def handle_call({:save_data, path, chunks, _opts}, _from, state) do
    do_save_data(path, chunks, state)
    {:reply, :ok, state}
  end

  defp do_save_data(path, chunks,
       %{header_string: header, feature_keys: keys} = _state) do
    File.open!(path, [:write], fn file ->
      IO.puts(file, header)
      Enum.each(chunks, & IO.puts(file, build_chunk_output(&1, keys)))
    end)
  end

  defp build_chunk_output([%{id: id} = target|non_target_deltas] = _chunk,
                          feature_keys) do
    data =
      [id, target[@pattern_key]] ++
      for delta <- non_target_deltas, key <- feature_keys do
        Map.fetch!(delta, key)
      end
    Enum.join(data, "\t")
  end
end
