defmodule Dirk.Ticker.K15 do
  use Ecto.Schema
  import Utils.Ecto, only: [in_time_range: 4]
  import Ecto.Query, only: [from: 2, order_by: 2, limit: 2]
  alias Dirk.Ticker.K15
  alias Dirk.Repo

  schema "k15_tickers" do
    field :op, :float
    field :la, :float
    field :hi, :float
    field :lo, :float
    field :vo, :float
    field :d_la, :float
    field :time, Ecto.DateTime
  end

  def get_d_la(%{la: curr_la, time: time}) do
    case in_time_range(time) do
      %K15{la: prev_la} -> (curr_la - prev_la) / prev_la
      nil               -> nil
    end
  end

  def order_by_time_desc(model \\ K15) do
    from t in model, order_by: [desc: :time]
  end

  @doc """
  This method is DEPRECATED since unique index on :time has been set. Use
  `order_by_time_desc/1` instead.
  """
  def distinct_on_time(model \\ K15) do
    from t in model, distinct: [desc: :time], order_by: [desc: :vo]
  end

  defp in_time_range(time) do
    in_time_range(K15, time, 300, -900)
    |> order_by(desc: :vo)
    |> limit(1)
    |> Repo.one
  end
end
