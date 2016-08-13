defmodule Azor.Ords.Tracker do
  use GenServer

  def start_link do
    GenStage.start_link(__MODULE__, :ok)
  end
end
