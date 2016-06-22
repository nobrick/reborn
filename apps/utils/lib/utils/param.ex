defmodule Utils.Param do
  @doc """
    Returns the corresponding URL query string of the given enumerable.

    ## Example:

        iex> Utils.Param.to_query(%{username: "johnsnow", nickname: "Snow"})
        "nickname=Snow&username=johnsnow"

    The string pairs `key=value` are sorted lexicographically in ascending
    order.
  """
  def to_query(enum) do
    enum
    |> Enum.sort
    |> Enum.map_join("&", fn {k, v} -> "#{k}=#{v}" end)
  end
end
