defmodule Reverie.SamplesCache do
  use GenServer
  require Logger
  alias Machine.DataGen

  @interval 45 * 60_000
  @samples_offset 10
  @samples_limit 10000

  ## API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def samples do
    GenServer.call(__MODULE__, :samples)
  end

  ## Callbacks

  def init(_) do
    Process.send(self(), :loop, [])
    {:ok, %{}}
  end

  def handle_call(:samples, _, %{samples: samples} = state) do
    {:reply, samples, state}
  end

  def handle_info(:loop, _state) do
    Process.send_after(self(), :loop, @interval)
    {time, samples} = :timer.tc(&fetch_samples/0)
    secs = Float.ceil(time / 1.0e6, 2)
    Logger.debug "Sample chunks fetched and computed in #{secs} secs." <>
                 " Total: #{Enum.count(samples)}"
    {:noreply, %{samples: samples}}
  end

  def handle_info(msg, state) do
    Logger.error "#{__MODULE__} received unexpected message: #{inspect msg}"
    {:noreply, state}
  end

  defp fetch_samples do
    DataGen.fetch_chunks(@samples_offset, @samples_limit, [])
  end
end
