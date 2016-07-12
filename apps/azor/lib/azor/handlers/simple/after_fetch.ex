defmodule Azor.Handlers.Simple.AfterFetch do
  use GenEvent
  alias Dirk.Ticker

  def init(_args) do
    {:ok, %{}}
  end

  def handle_event({:after_fetch, _mode, ret}, state) do
    case ret do
      {:ok, %Ticker{}} ->
        ret
      _ ->
        ret
    end
    {:ok, state}
  end
end
