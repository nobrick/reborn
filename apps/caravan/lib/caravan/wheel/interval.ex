defmodule Caravan.Wheel.Interval do
  use GenServer
  import Task.Supervisor, only: [start_child: 4]
  alias Caravan.Wheel

  @doc """
    Starts Wheel.Interval instance.

    ## Options

    - `interval_sup`: The `Task.Supervisor` for supervising periodically
    pulling processes. `Caravan.Wheel.Interval.Supervisor` by default.

    - `wheel`: The wheel instance for pulling. `Caravan.Wheel` by default.

    - `mode`: The mode for pulling. :simple by default.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, extract_options(opts))
  end

  @interval_sup Wheel.Interval.Supervisor

  defp extract_options(opts) do
    {wheel, opts} = Keyword.pop(opts, :wheel, Wheel)
    {mode, opts} = Keyword.pop(opts, :mode, :simple)
    {interval_sup, _} = Keyword.pop(opts, :interval_sup, @interval_sup)
    %{wheel: wheel, mode: mode, interval_sup: interval_sup}
  end

  ## Callbacks

  def init(state) do
    Process.send(self(), :pull, [])
    {:ok, state}
  end

  def handle_info(:pull, %{interval_sup: interval_sup, wheel: wheel,
      mode: mode} = state) do
    start_child(interval_sup, Wheel, :pull, [wheel, mode])
    Process.send_after(self(), :pull, 5000)
    {:noreply, state}
  end
end
