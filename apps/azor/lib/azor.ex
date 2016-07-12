defmodule Azor do
  use Application
  alias Azor.Handlers.Watcher

  @simple_handler Azor.Handlers.Simple.AfterFetch

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Watcher, watcher_args(:simple, @simple_handler))
    ]

    opts = [strategy: :one_for_one, name: Azor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp watcher_args(mode, handler) do
    [%{mode: mode, handler: handler}, [name: Watcher]]
  end
end
