defmodule Caravan.Wheel do
  use GenServer

  ## API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def pull(pid, mode \\ :simple) do
    GenServer.call(pid, {:pull, mode, []})
  end

  def fetch(pid, mode \\ :simple) do
    GenServer.call(pid, {:pull, mode, fetch_only: true})
  end

  ## Callbacks

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:pull, mode, opts}, _from, state) do
    handler = handler_for(mode)
    case Huo.Market.get(mode) do
      {:ok, %{body: body}} ->
        if Keyword.get(opts, :fetch_only, false) do
          {:reply, handler.handle_fetch(body), state}
        else
          {:reply, handler.handle_pull(body), state}
        end
      error ->
        {:reply, {:error, :huo_market, error}, state}
    end
  end

  ## Helpers

  defp handler_for(:simple), do: Caravan.Wheel.Modes.Simple
end
