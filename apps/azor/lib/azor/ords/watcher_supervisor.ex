defmodule Azor.Ords.WatcherSupervisor do
  use Supervisor
  alias Azor.Ords.Watcher

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def start_child(args, opts \\ [])
      when is_map(args) and is_list(opts) do
    Supervisor.start_child(__MODULE__, [args, opts])
  end

  def terminate_child(pid) when is_pid(pid) do
    Supervisor.terminate_child(__MODULE__, pid)
  end

  def terminate_child(oid, context) when is_integer(oid) do
    case Watcher.whereis(oid, context) do
      pid when is_pid(pid) -> terminate_child(pid)
      _                    -> {:error, :not_found}
    end
  end

  def init(:ok) do
    children = [
      worker(Watcher, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
