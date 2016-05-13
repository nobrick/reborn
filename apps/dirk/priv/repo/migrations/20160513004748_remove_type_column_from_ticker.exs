defmodule Dirk.Repo.Migrations.RemoveTypeColumnFromTicker do
  use Ecto.Migration

  def up do
    alter table(:ticker) do
      remove :type
    end
  end

  def down do
    alter table(:ticker) do
      add :type, :string, size: 15
    end
  end
end
