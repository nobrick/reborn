defmodule Huo.Market do
  @simple_base "http://api.huobi.com/staticmarket/ticker_btc_json.js"
  @detail_base "http://api.huobi.com/staticmarket/detail_btc_json.js"
  @kline_1min_base "http://api.huobi.com/staticmarket/btc_kline_001_json.js_json.js"

  def get(:simple), do: get(:simple, @simple_base)
  def get(:detail), do: get(:detail, @detail_base)
  def get(:k1), do: get(:kline, @kline_1min_base)

  defp get(_mode, base_url) do
    response = HTTPoison.get(base_url)
    case response do
      {:ok, %{status_code: 200, body: body} = result} ->
        body = body |> Poison.decode!
        {:ok, %{result | body: body} |> Map.from_struct}
      {:ok, result} ->
        {:bad_status, result}
      _ ->
        response
    end
  end
end
