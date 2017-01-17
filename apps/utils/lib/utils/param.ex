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

  @doc """
    Converts the map response into formatted form.
    
    The method transitions number string values into float values.
  """
  def format_resp(resp) when is_map(resp) do
    for {k, v} <- resp, into: %{}, do: {k, to_float(v)}
  end

  def format_resp(resp), do: resp

  ## Helpers

  defp to_float(str) when is_binary(str) do
    if Regex.match?(~r/\d+\.\d+/, str) or Regex.match?(~r/\d+/, str) do
      String.to_float(str)
    else
      str
    end
  end

  defp to_float(str), do: str
end
