defmodule Huo.Order do
  alias Utils.Param

  @api_base "https://api.huobi.com/apiv3"
  @api_header [{"Content-Type", "application/x-www-form-urlencoded"},
               {"Accept", "application/json"}]
  @access_key Application.get_env(:huo, :access_key)
  @secret_key Application.get_env(:huo, :secret_key)

  def get_account_info do
    get(%{method: :get_account_info})
  end

  def get_orders do
    get(%{method: :get_orders, coin_type: 1})
  end

  def get_new_deal_orders do
    get(%{method: :get_new_deal_orders, coin_type: 1})
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
