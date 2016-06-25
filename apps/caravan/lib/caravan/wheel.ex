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

  def pull(pid, mode \\ :simple, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @timeout)
    GenServer.call(pid, {:pull, mode, []}, timeout)
  end

  def fetch(pid, mode \\ :simple, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @timeout)
    GenServer.call(pid, {:pull, mode, fetch_only: true}, timeout)
  end

  def add_callback(pid, :after_fetch, handler, mode \\ :simple, args \\ []) do
    GenServer.call(pid, {:add_callback, :after_fetch, handler, mode, args})
  end

  def get_callback(pid, :after_fetch, mode) do
    GenServer.call(pid, {:get_callback, :after_fetch, mode})
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

    state
    |> callback_for(mode)
    |> GenEvent.sync_notify({:after_fetch, mode, ret})

    {:reply, ret, state}
  end

  def handle_call({:add_callback, :after_fetch, handler, mode, args},
      _from, state) do
    ret = state |> callback_for(mode) |> GenEvent.add_handler(handler, args)
    {:reply, ret, state}
  end

  def handle_call({:get_callback, :after_fetch, mode}, _from, state) do
    {:reply, callback_for(state, mode), state}
  end

  ## Helpers

  defp callback_for(state, mode) when mode in [:simple, :k15] do
    get_in(state, [:callback_managers, :after_fetch, mode])
  end

  defp handler_for(:simple), do: Caravan.Wheel.Modes.Simple
  defp handler_for(:k15), do: Caravan.Wheel.Modes.K15
end
