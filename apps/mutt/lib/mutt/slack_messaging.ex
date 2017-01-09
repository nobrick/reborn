defmodule Mutt.SlackMessaging.API.State do
  @moduledoc """
  A server that manages the `%{Slack.State}` struct fetched by
  `Mutt.SlackMessaging.API`.
  """

  use GenServer

  @name __MODULE__

  def start_link do
    GenServer.start_link(__MODULE__, %{slack: nil}, [name: @name])
  end

  def set_slack(pid \\ @name, slack) do
    GenServer.call(pid, {:set_slack, slack})
  end

  def slack(pid \\ @name) do
    GenServer.call(pid, :slack)
  end

  def handle_call({:set_slack, slack}, _from, state) do
    {:reply, :ok, Map.put(state, :slack, slack)}
  end

  def handle_call(:slack, _from, %{slack: slack} = state) do
    {:reply, slack, state}
  end
end

alias Mutt.SlackMessaging.API.State

defmodule Mutt.SlackMessaging.API do
  @moduledoc false

  use Slack

  def post_message(text, channel, slack) do
    send_message(text, channel, slack)
  end

  def handle_connect(slack) do
    State.set_slack(slack)
    IO.puts "#{__MODULE__} connected as #{slack.me.name}"
  end

  def handle_message(%{type: "message", text: text}, _slack) do
    IO.puts "#{__MODULE__} received text message: #{text}"
  end

  def handle_message(_, _), do: :ok
end

defmodule Mutt.SlackMessaging do
  @moduledoc """
  Real-time messaging for Slack.

  Behind the scenes, this module uses `GenServer` to manage the process in
  order to be supervised in the supervisor tree of the app, with another
  GenServer instance `Mutt.SlackMessaging.API.State` storing the `Slack.State`
  struct returned by `Mutt.SlackMessaging.API.start_link/1` in its state.
  """

  use GenServer
  
  @name __MODULE__
  @api Mutt.SlackMessaging.API
  @default_channel Application.get_env(:mutt, :default_channel)

  @doc """
  Starts a server instance of `Mutt.SlackMessaging`.
  """
  def start_link(%{token: _} = args, opts \\ []) do
    opts = Keyword.put_new(opts, :name, @name)
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Posts a message to the slack channel.
  """
  def post_message(pid \\ @name, text) do
    GenServer.call(pid, {:post_message, text}, 8000)
  end

  @doc """
  Inspects the `GenServer` state.
  """
  def state(pid \\ @name) do
    GenServer.call(pid, :state)
  end

  ## Callbacks

  def init(%{token: _} = args) do
    state = args |> Map.put_new(:channel, @default_channel)
    send(self(), :start_slack)
    {:ok, state}
  end

  def handle_info(:start_slack, %{token: token} = state) do
    {:ok, pid} = @api.start_link(token)
    {:noreply, Map.merge(state, %{websocket_client_pid: pid})}
  end

  def handle_call({:post_message, text}, _from, %{channel: channel} = state) do
    slack = State.slack
    @api.post_message(text, channel, slack)
    {:reply, :ok, state}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end
end
