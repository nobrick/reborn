defmodule Huo.Market do
  @simple_base "http://api.huobi.com/staticmarket/ticker_btc_json.js"
  @detail_base "http://api.huobi.com/staticmarket/detail_btc_json.js"
  @depth_base "http://api.huobi.com/staticmarket/depth_btc_150.js"
  @k1_base "http://api.huobi.com/staticmarket/btc_kline_001_json.js_json.js"
  @k15_base "http://api.huobi.com/staticmarket/btc_kline_015_json.js_json.js"

  def get(:simple), do: do_get(:simple, @simple_base)
  def get(:detail), do: do_get(:detail, @detail_base)
  def get(:depth), do: do_get(:detail, @depth_base)
  def get(:k1), do: do_get(:kline, @k1_base)
  def get(:k15), do: get(:k1_recent, 2000)
  # def get(:k15), do: do_get(:kline, @k15_base)

  def get(:k1_recent, count) do
    do_get(:kline, "#{@k1_base}?length=#{count}")
  end

  def get(:k15_recent, count) do
    do_get(:kline, "#{@k15_base}?length=#{count}")
  end

  defp do_get(_mode, base_url) do
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
