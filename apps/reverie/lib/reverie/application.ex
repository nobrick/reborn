defmodule Reverie.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Task.Supervisor,
                 [[name: Reverie.TransientTaskSup]], id: 1,
                 restart: :transient, max_restart: 5),
      supervisor(Task.Supervisor,
                 [[name: Reverie.TemporaryTaskSup]], id: 2),
      #worker(Reverie.OrdsManager, [[name: Reverie.OrdsManager]]),
      #worker(Reverie.Wheel, [[name: Reverie.Wheel]]),
      #worker(Reverie.SamplesCache, [[name: Reverie.SamplesCache]])
      #worker(Reverie, [[name: Reverie]])
    ]

    opts = [strategy: :one_for_one, name: Reverie.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
