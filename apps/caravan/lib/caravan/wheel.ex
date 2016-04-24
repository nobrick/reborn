defmodule Caravan.Wheel do
  use GenServer
  alias Caravan.Wheel.SimpleMode

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
          handle_fetch(handler, body, state)
        else
          handle_pull(handler, body, state)
        end
      error ->
        {:reply, {:error, :huo_market, error}, state}
    end
  end

  def handle_pull(handler, body, state) do
    case handler.insert(body) do
      {:ok, struct} ->
        {:reply, {:ok, struct}, state}
      {:error, changeset} ->
        {:reply, {:error, :changeset, changeset}, state}
    end
  end

  def handle_fetch(handler, body, state) do
    {:reply, {:ok, handler.map_to_ticker(body)}, state}
  end

  defp handler_for(:simple), do: SimpleMode
end
