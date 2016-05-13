defmodule Dirk.Repo.Migrations.RenameTickerToTickers do
  use Ecto.Migration

  def up do
    rename table(:ticker), to: table(:tickers)
  end

  def down do
    rename table(:tickers), to: table(:ticker)
  end
end
