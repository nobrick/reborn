defmodule Caravan.Wheel do
  use GenServer

  ## API

  @doc """
    Starts Caravan.Wheel instance.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @timeout 8000

  @doc """
    Fetches data remotely and writes it into the database.
  """
  def pull(pid, mode \\ :simple, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @timeout)
    GenServer.call(pid, {:pull, mode, []}, timeout)
  end

  @doc """
    Fetches data for the given `mode`.
  """
  def fetch(pid, mode \\ :simple, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @timeout)
    GenServer.call(pid, {:pull, mode, fetch_only: true}, timeout)
  end

  @doc """
    Adds event handler for after-fetching GenEvent manager.
  """
  def add_event_handler(pid, :after_fetch, handler, mode \\ :simple, args \\ []) do
    GenServer.call(pid, {:add_event_handler, :after_fetch, handler, mode, args})
  end

  @doc """
    Gets after-fetching GenEvent manager.
  """
  def get_event_manager(pid, :after_fetch, mode) do
    GenServer.call(pid, {:get_event_manager, :after_fetch, mode})
  end

  ## Callbacks

  def init(:ok) do
    {:ok, simple} = GenEvent.start_link([])
    {:ok, k15}    = GenEvent.start_link([])
    {:ok, %{callback_managers: %{after_fetch: %{simple: simple, k15: k15}}}}
  end

  def handle_call({:pull, mode, opts}, _from, state) do
    ret = case Huo.Market.get(mode) do
      {:ok, %{body: body}} ->
        fetch_only = Keyword.get(opts, :fetch_only, false)
        h = handler_for(mode)
        if fetch_only, do: h.handle_fetch(body), else: h.handle_pull(body)
      error ->
        {:error, :huo_market, error}
    end
    notify(:after_fetch, state, mode, ret)
    {:reply, ret, state}
  end

  def handle_call({:add_event_handler, :after_fetch, handler, mode, args},
      _from, state) do
    ret = state |> callback_for(mode) |> GenEvent.add_handler(handler, args)
    {:reply, ret, state}
  end

  def handle_call({:get_event_manager, :after_fetch, mode}, _from, state) do
    {:reply, callback_for(state, mode), state}
  end

  ## Helpers

  defp notify(msg, state, mode, ret) do
    state
    |> callback_for(mode)
    |> GenEvent.sync_notify({msg, mode, ret})
  end

  defp callback_for(state, mode) when mode in [:simple, :k15] do
    get_in(state, [:callback_managers, :after_fetch, mode])
  end

  defp handler_for(:simple), do: Caravan.Wheel.Modes.Simple
  defp handler_for(:k15), do: Caravan.Wheel.Modes.K15
end
