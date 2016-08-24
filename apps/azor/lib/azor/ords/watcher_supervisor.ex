defmodule Azor.Ords.WatcherSupervisor do
  use Supervisor

  @watcher Azor.Ords.Watcher

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def start_child(args, opts \\ [])
      when is_map(args) and is_list(opts) do
    Supervisor.start_child(__MODULE__, [args, opts])
  end

  def terminate_child(pid) do
    Supervisor.terminate_child(__MODULE__, pid)
  end

  def init(:ok) do
    children = [
      worker(@watcher, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
