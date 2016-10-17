defmodule Dirk.Repo.Migrations.AddOrdsTable do
  use Ecto.Migration

  def up do
    create table(:ords) do
      add :ord_id,        :integer
      add :ord_p,         :float
      add :ord_amt,       :float
      add :processed_p,   :float
      add :processed_amt, :float
      add :vot,           :float
      add :total,         :float
      add :fee,           :float
      add :type,          :string
      add :state,         :string
      add :remote_status, :string
    end
  end

  def down do
    drop table(:ords)
  end
end
