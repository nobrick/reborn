defmodule Caravan.Wheel.Modes.K15 do
  alias Dirk.Repo
  alias Dirk.Ticker.K15

  ## API

  def handle_fetch(body) do
    {:ok, map_resp(body)}
  end

  def handle_pull(body) do
    Repo.insert_all("k15_tickers", body |> map_resp)
  end

  ## Helpers

  defp map_resp(body) do
    body |> Enum.map(&to_ticker_map/1)
  end

  defp to_ticker_map([time, op, hi, lo, la, vo]) do
    %{op: op, la: la, hi: hi, lo: lo, vo: vo, time: time |> to_time}
  end

  defp insert_all(body) do
    Repo.insert_all("k15_tickers", body)
  end

  defp to_time(str) do
    str
    |> capture_time_str
    |> Utils.Time.from_local
    |> Ecto.DateTime.cast!
  end

  @time_format ~r/\A(?<y>\d{4})(?<m>\d{2})(?<d>\d{2})(?<hh>\d{2})(?<mm>\d{2})(?<ss>\d{2})/
  defp capture_time_str(time_str) do
    %{y: y, m: m, d: d, hh: hh, mm: mm, ss: ss} = @time_format
    |> Regex.named_captures(time_str)
    |> Enum.map(fn {k, v} -> {String.to_atom(k), String.to_integer(v)} end)
    |> Enum.into(%{})
    {{y, m, d}, {hh, mm, ss}}
  end
end
