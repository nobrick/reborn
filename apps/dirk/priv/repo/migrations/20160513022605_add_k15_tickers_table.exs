defmodule Dirk.Repo.Migrations.AddK15TickersTable do
  use Ecto.Migration

  def up do
    create table(:k15_tickers) do
      add :op, :float
      add :la, :float
      add :hi, :float
      add :lo, :float
      add :vo, :float
      add :d_la, :float
      add :time, :datetime
    end
  end

  def down do
    drop table(:k15_tickers)
  end
end
