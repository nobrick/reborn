defmodule Machine.Indicators do
  @moduledoc """
  This module defines indicator functions.
  """

  def run({:sma, period}, payload) do
    __MODULE__.SMA.run(payload, period)
  end
end
