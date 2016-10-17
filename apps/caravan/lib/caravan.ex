defmodule Caravan do
  use Application
  alias Caravan.Wheel
  alias Caravan.Wheel.Broadcaster

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Task.Supervisor, [[name: Wheel.Interval.Supervisor]]),
      worker(Wheel, [[name: Wheel]]),
      worker(Broadcaster, [[name: Wheel.Simple.Broadcaster]], id: 1),
      worker(Broadcaster, [[name: Wheel.K15.Broadcaster]],    id: 2)
    ]

    opts = [strategy: :one_for_one, name: Caravan.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
