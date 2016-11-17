defmodule Machine do
  use Application

  alias Machine.Adapters.CloudForest.DataWriter

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(DataWriter, [%{}, [name: DataWriter]])
    ]

    opts = [strategy: :one_for_one, name: Machine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
