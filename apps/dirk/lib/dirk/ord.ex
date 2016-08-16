defmodule Dirk.Ord do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ords" do
    field :ord_id,        :integer
    field :ord_p,         :float
    field :ord_amt,       :float
    field :processed_p,   :float
    field :processed_amt, :float
    field :vot,           :float
    field :total,         :float
    field :fee,           :float
    field :type,          :string
    field :state,         :string
    field :remote_status, :string
  end

  @required_fields ~w(ord_id ord_amt type state)
  @allowed_fields  ~w(ord_id ord_p ord_amt processed_p processed_amt vot total
                      fee type state remote_status)
  @types           ~w(bi of bi_mkt of_mkt)
  @remote_statuses ~w(undone partial_done done canceled _deprecated exception
                      partial_canceled in_queue)
  @states          ~w(initial watched processing pending completed void)

  def changeset(model, params) do
    model
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:remote_status, @remote_statuses)
    |> validate_inclusion(:state, @states)
  end

  def remote_status(index) when index in 0..7 do
    Enum.at(@remote_statuses, index)
  end

  def type(index) when index in 1..4 do
    Enum.at(@types, index - 1)
  end
end
