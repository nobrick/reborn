defmodule Dirk.Ticker do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  schema "ticker" do
    field :op, :float
    field :la, :float
    field :hi, :float
    field :lo, :float
    field :vo, :float
    field :of, :float
    field :bi, :float
    field :d_la, :float
    field :type, :string, default: "line"
    field :time, Ecto.DateTime
  end

  @required_fields ~w(op la hi lo vo type time)
  @optional_fields ~w(of bi d_la)

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end

  def in_time_range(query, time, margin) do
    time = Ecto.DateTime.cast!(time)
    from(t in query,
      where: t.time > datetime_add(^time, ^-margin, "second")
         and t.time < datetime_add(^time, ^margin, "second"))
  end
end
