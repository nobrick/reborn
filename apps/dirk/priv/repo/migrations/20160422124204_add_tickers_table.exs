defmodule Dirk.Repo.Migrations.AddTickersTable do
  use Ecto.Migration

  def up do
    create table(:ticker) do
      add :op, :float
      add :la, :float
      add :hi, :float
      add :lo, :float
      add :vo, :float
      add :of, :float
      add :bi, :float
      add :type, :string, size: 15
      add :time, :datetime
    end

    create index(:ticker, [:type, :time])
  end

  def down do
    drop table(:ticker)
  end
end
