defmodule Dirk.Repo.Migrations.AddIndexToK15Tickers do
  use Ecto.Migration

  def change do
    create index(:k15_tickers, [:time])
  end
end
