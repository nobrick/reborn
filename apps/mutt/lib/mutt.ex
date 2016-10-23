defmodule Mutt do
  use Application

  @slack_token Application.get_env(:slack, :api_token)

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Mutt.SlackMessaging, [%{token: @slack_token}]),
      worker(Mutt.SlackMessaging.API.State, [])
    ]

    opts = [strategy: :one_for_one, name: Mutt.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
