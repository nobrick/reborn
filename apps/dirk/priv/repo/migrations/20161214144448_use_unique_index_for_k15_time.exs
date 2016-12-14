defmodule Dirk.Repo.Migrations.UseUniqueIndexForK15Time do
  use Ecto.Migration

  def change do
    drop index(:k15_tickers, [:time])
    create index(:k15_tickers, [:time], unique: true)
  end
end
