defmodule Huo.Market do
  @simple_base  'http://api.huobi.com/staticmarket/ticker_btc_json.js'
  @detail_base  'http://api.huobi.com/staticmarket/detail_btc_json.js'

  def get(:simple) do
    HTTPoison.start
    response = HTTPoison.get(@simple_base)
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
