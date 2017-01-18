defmodule Huo.Order do
  alias Utils.Param

  @api_base     "https://api.huobi.com/apiv3"
  @api_header   [{"Content-Type", "application/x-www-form-urlencoded"},
                 {"Accept", "application/json"}]
  @access_key   Application.get_env(:huo, :access_key)
  @secret_key   Application.get_env(:huo, :secret_key)

  # The `in_queue` status will be removed in the next API version.
  @ord_statuses ~w(undone partial_done done canceled _deprecated exception
                   partial_canceled in_queue)
  @ord_types    ~w(bi of bi_mkt of_mkt)

  def get_account do
    get(%{method: :get_account_info})
  end

  @doc """
  Gets all the currently ongoing ords.

  Returns a tuple with `:ok` followed by a list when succeeds:
      {:ok, [%{"id" => 1813009991, "order_amount" => "0.0100",
               "order_price" => "3000.00", "order_time" => 1471347924,
               "processed_amount" => "0.0000", "type" => "bi"}]}
  """
  def get_ords do
    ret = get(%{method: :get_orders, coin_type: 1})
    with {:ok, ords} when is_list(ords) <- ret do
      {:ok, Enum.map(ords, fn %{"type" => type} = ord ->
              Param.format_resp(%{ord|"type" => ord_type_by(type)})
            end)}
    end
  end

  @doc """
  Gets ord info.

  Returns a tuple with `:ok` followed by a map when succeeds:

      {:ok, %{"fee" => 0.0, "id" => 1813009991, "order_amount" => 0.01,
              "order_price" => 3.0e3, "processed_amount" => 0.0,
              "processed_price" => 0.0, "status" => "undone", "total" => 0.0,
              "type" => "bi", "vot" => 0.0}}
  """
  def get_ord(id) do
    ret = get(%{method: :order_info, coin_type: 1, id: id})
    with {:ok, %{"type" => type, "status" => status} = ord} <- ret do
      {:ok, %{ord|"type"   => ord_type_by(type),
                  "status" => ord_status_by(status)}}
    end
  end

  @doc """
  Add BI ord.

  ## Arguments

      `amt`: btc amt.

  Returns a tuple in the following form when succeeds:

      {:ok, %{"id" => 1689495778, "result" => "success"}}
  """
  def bi(p, amt) do
    get(%{method: :buy, coin_type: 1, price: p, amount: amt})
  end

  @doc """
  Add OF ord.

  Returns a tuple in the following form when succeeds:

      {:ok, %{"id" => 1689495778, "result" => "success"}}
  """
  def of(p, amt) do
    get(%{method: :sell, coin_type: 1, price: p, amount: amt})
  end

  @doc """
  Add BI_MKT ord.

  ## Arguments
  
      `cny_amt` - CNY amt.

  Returns a tuple in the following form when succeeds:

      {:ok, %{"id" => 1689495778, "result" => "success"}}
  """
  def bi_mkt(cny_amt) do
    get(%{method: :buy_market, coin_type: 1, amount: cny_amt})
  end

  @doc """
  Add OF_MKT ord.

  ## Arguments

      `amt` - BTC amt.

  Returns a tuple in the following form when succeeds:

      {:ok, %{"id" => 1689495778, "result" => "success"}}
  """
  def of_mkt(amt) do
    get(%{method: :sell_market, coin_type: 1, amount: amt})
  end

  @doc """
  Cancel ord.

  Returns a tuple in the following form when succeeds:

      {:ok, %{"result" => "success"}}
  """
  def cancel_ord(id) do
    get(%{method: :cancel_order, coin_type: 1, id: id})
  end

  def get_recent_ords do
    get(%{method: :get_new_deal_orders, coin_type: 1})
  end

  def get_ord_id_by_trd_id(id) do
    get(%{method: :get_order_id_by_trade_id, coin_type: 1, trade_id: id})
  end

  def withdraw(addr, amt) do
    get(%{method: :withdraw_coin,
          coin_type: 1,
          withdraw_address: addr,
          withdraw_amount: amt})
  end

  def cancel_withdrawal(id) do
    get(%{method: :cancel_withdraw_coin, withdraw_coin_id: id})
  end

  def transfer(from, to, amt) do
    get(%{account_from: from, account_to: to, amount: amt, coin_type: 1})
  end

  ## Helpers

  defp get(%{method: _} = params, opts \\ []) do
    {digest_keys, _} = Keyword.pop(opts, :digest_keys, Map.keys(params))
    params = pack_params(params, digest_keys)
    case HTTPoison.get(@api_base, @api_header, params: params) do
      {:ok, %{status_code: 200, body: body}} -> process_resp_body(body)
      {:ok, response}                        -> {:error, :status, response}
      {:error, reason}                       -> {:error, :http, reason}
    end
  end

  defp process_resp_body(body) do
    case normalize_json(body) do
      %{"code" => code, "msg" => _} = err when code != 0 ->
        {:error, :invalid, err}
      ord ->
        {:ok, ord}
    end
  end

  defp normalize_json(json) do
    json
    |> Poison.decode!
    |> Param.format_resp
  end

  defp pack_params(params, digest_keys) do
    params
    |> with_created_at
    |> with_tokens
    |> with_signature(digest_keys)
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
    sig = digest_params
          |> Param.to_query
          |> md5
    Map.put(params, :sign, sig)
  end

  defp md5(text) do
    :crypto.hash(:md5, text) |> Base.encode16(case: :lower)
  end

  defp ord_status_by(index) when index in 0..7 do
    Enum.at(@ord_statuses, index)
  end

  defp ord_type_by(index) when index in 0..4 do
    Enum.at(@ord_types, index - 1)
  end
end
