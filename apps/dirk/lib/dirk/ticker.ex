defmodule Dirk.Ticker do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ticker" do
    field :op, :float
    field :la, :float
    field :hi, :float
    field :lo, :float
    field :vo, :float
    field :of, :float
    field :bi, :float
    field :type, :string, default: "line"
    field :time, Ecto.DateTime
  end

  @required_fields ~w(op la hi lo vo type time)
  @optional_fields ~w(of bi)

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
