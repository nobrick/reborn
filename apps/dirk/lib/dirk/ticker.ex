defmodule Dirk.Ticker do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias Dirk.Ticker

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

  @doc """
  Queries in the given time range.

    * `query`: The input query for chaining.
    * `time`: The base time.
    * `margin`: The margin of the time range in the unit of `second`.
    * `offset`: The range offset based on `time` in the unit of `second`.
                Defaults to 0.
  """
  def in_time_range(query, time, margin, offset \\ 0) do
    time = Ecto.DateTime.cast!(time)
    from(t in query,
      where: t.time > datetime_add(^time, ^(offset - margin), "second")
         and t.time < datetime_add(^time, ^(offset + margin), "second"))
  end
end
