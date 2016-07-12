defmodule Azor.Handlers.Watcher do
  use GenServer
  alias Caravan.Wheel

  @modes [:simple, :k15]

  ## API

  def start_link(%{handler: _, mode: mode} = args, opts \\ [])
      when mode in @modes do
    state = args
            |> Map.put_new(:wheel, Wheel)
            |> Map.take([:handler, :mode, :wheel])
    GenServer.start_link(__MODULE__, state , opts)
  end

  ## Callbacks

  def init(%{wheel: _, handler: _, mode: _} = state) do
    start_handler(state)
    {:ok, state}
  end

  def handle_info({:gen_event_EXIT, _handler, _reason}, state) do
    start_handler(state)
  end

  ## Helpers

  defp get_manager(wheel, mode) when mode in @modes do
    Wheel.get_event_manager(wheel, :after_fetch, mode)
  end

  defp start_handler(%{wheel: wheel, handler: handler, mode: mode} = _state) do
    wheel
    |> get_manager(mode)
    |> start_handler(handler)
  end

  defp start_handler(manager, handler)
       when is_pid(manager) and is_atom(handler) do
    :ok = GenEvent.add_mon_handler(manager, handler, [])
  end
end
