defmodule Utils.Number do
  def floor(number, precision \\ 6)
  def floor(number, _) when is_integer(number), do: number / 1
  def floor(number, precision), do: Float.floor(number, precision)
end
