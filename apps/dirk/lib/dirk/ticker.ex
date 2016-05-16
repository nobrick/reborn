defmodule Dirk.Ticker do
  use Ecto.Schema
  import Ecto.Changeset
  import Utils.Ecto, only: [in_time_range: 4]
  alias Dirk.Ticker
  alias Dirk.Repo

  schema "tickers" do
    field :op, :float
    field :la, :float
    field :hi, :float
    field :lo, :float
    field :vo, :float
    field :of, :float
    field :bi, :float
    field :d_la, :float
    field :time, Ecto.DateTime
  end

  @required_fields ~w(op la hi lo vo time)
  @optional_fields ~w(of bi d_la)

  def changeset(:create, model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> set_d_la
  end

  defp set_d_la(changeset) do
    {:ok, time} = fetch_change(changeset, :time)
    case Repo.all(in_time_range(Ticker, time, 0.5, -1)) do
      [prev_model | _] ->
        set_d_la(changeset, prev_model)
      [] ->
        put_change(changeset, :d_la, nil)
    end
  end

  defp set_d_la(changeset, %Ticker{la: prev_la} = _prev_model) do
    {:ok, curr_la} = fetch_change(changeset, :la)
    d_la = (curr_la - prev_la) / prev_la
    put_change(changeset, :d_la, d_la)
  end
end
