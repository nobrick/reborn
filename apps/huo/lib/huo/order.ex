defmodule Huo.Order do
  alias Utils.Param

  @api_base "https://api.huobi.com/apiv3"
  @api_header [{"Content-Type", "application/x-www-form-urlencoded"},
               {"Accept", "application/json"}]
  @access_key Application.get_env(:huo, :access_key)
  @secret_key Application.get_env(:huo, :secret_key)

  def get_account do
    get(%{method: :get_account_info})
  end

  def get_ords do
    get(%{method: :get_orders, coin_type: 1})
  end

  def get_ord(id) do
    get(%{method: :order_info, coin_type: 1, id: id})
  end

  def bid(price, amount) do
    get(%{method: :buy, coin_type: 1, price: price, amount: amount})
  end

  def offer(price, amount) do
    get(%{method: :sell, coin_type: 1, price: price, amount: amount})
  end

  def bid_mkt(amount) do
    get(%{method: :buy_market, coin_type: 1, amount: amount})
  end

  def offer_mkt(amount) do
    get(%{method: :sell_market, coin_type: 1, amount: amount})
  end

  def cancel_ord(id) do
    get(%{method: :cancel_order, coin_type: 1, id: id})
  end

  def get_recent_ords do
    get(%{method: :get_new_deal_orders, coin_type: 1})
  end

  def get_ord_id_by_trd_id(id) do
    get(%{method: :get_order_id_by_trade_id, coin_type: 1, trade_id: id})
  end

  def withdraw(addr, amount) do
    get(%{method: :withdraw_coin,
          coin_type: 1,
          withdraw_address: addr,
          withdraw_amount: amount})
  end

  def cancel_withdrawal(id) do
    get(%{method: :cancel_withdraw_coin, withdraw_coin_id: id})
  end

  def transfer(from, to, amount) do
    get(%{account_from: from, account_to: to, amount: amount, coin_type: 1})
  end

  defp get(%{method: _} = params, opts \\ []) do
    {digest_keys, _} = Keyword.pop(opts, :digest_keys, Map.keys(params))
    params = pack_params(params, digest_keys)
    case HTTPoison.get(@api_base, @api_header, params: params) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, normalize_json(body)}
      {:ok, response} ->
        {:error, :status, response}
      {:error, reason} ->
        {:error, :http, reason}
    end
  end

  defp normalize_json(json) do
    Poison.decode!(json)
  end

  defp pack_params(params, digest_keys) do
    params |> with_created_at |> with_tokens |> with_signature(digest_keys)
  end

  defp with_created_at(params) do
    Map.put(params, :created, :os.system_time(:seconds))
  end

  defp with_tokens(params) do
    Map.merge(params, %{access_key: @access_key, secret_key: @secret_key})
  end

  defp with_signature(params, digest_keys) do
    digest_keys = digest_keys ++ [:access_key, :secret_key, :created]
    {digest_params, _} = Map.split(params, digest_keys)
    sig = digest_params |> Param.to_query |> md5
    Map.put(params, :sign, sig)
  end

  defp md5(text) do
    :crypto.hash(:md5, text) |> Base.encode16(case: :lower)
  end
end
