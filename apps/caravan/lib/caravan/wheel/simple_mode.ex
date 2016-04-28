defmodule Caravan.Wheel.SimpleMode do
  alias Dirk.Repo
  alias Dirk.Ticker

  def map_to_ticker(body), do: struct!(Ticker, map_resp(body))

  def map_resp(%{"ticker" => %{"buy" => bi, "high" => hi, "last" => la, "low"
      => lo, "open" => op, "sell" => of, "vol" => vo}, "time" => time}) do
    time = time
    |> String.to_integer
    |> Utils.Time.from_unix_timestamp
    %{op: op, la: la, hi: hi, lo: lo, vo: vo, of: of, bi: bi, time: time}
  end

  def insert(body) do
    Ticker.changeset(:create, %Ticker{}, map_resp(body))
    |> Repo.insert
  end
end
