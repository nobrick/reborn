defmodule Dirk.Ticker do
  use Ecto.Schema

  schema "ticker" do
    field :bid, :float
    field :sel, :float
    field :vol, :float
    field :open, :float
    field :last, :float
  end
end
