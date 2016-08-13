defmodule Azor.Ords.WatcherSupervisor do
  use Supervisor

  @watcher Azor.Ords.Watcher

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      worker(@watcher, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
