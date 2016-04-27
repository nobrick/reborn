defmodule Dirk.Repo.Migrations.AddsDLaColumnToTicker do
  use Ecto.Migration

  def change do
    alter table(:ticker) do
      add :d_la, :float
    end
  end
end
