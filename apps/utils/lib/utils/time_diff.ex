defmodule Utils.TimeDiff do
  @format "{ISO:Extended:Z}"

  @doc """
  Compares two datetimes formatted in ISO8601 string or Ecto.DateTime with
  given `granularity`.

  The first datetime adds an duration shift given by `shift` and `granularity`
  before comparing. The method returns an integer in [-1, 0, 1].

  ## Examples

      iex> Utils.TimeDiff.compare("2016-02-29T22:00:00Z",
           "2016-02-29T22:25:00", 25, :minutes)

  """
  def compare(time_0, time_1, shift, granularity \\ :minutes)

  def compare(%Ecto.DateTime{} = time_0, %Ecto.DateTime{} = time_1, shift,
      granularity) when is_integer(shift) do
    iso_0 = Ecto.DateTime.to_iso8601(time_0) <> "Z"
    iso_1 = Ecto.DateTime.to_iso8601(time_1) <> "Z"
    compare(iso_0, iso_1, shift, granularity)
  end

  def compare(time_0, time_1, shift, granularity)
      when is_binary(time_0) and is_binary(time_1) and is_integer(shift) do
    utc_0 = Timex.parse!(time_0, @format)
    utc_1 = Timex.parse!(time_1, @format)
    utc_0_shifted = if shift == [] do
                      utc_0
                    else
                      Timex.shift(utc_0, [{granularity, shift}])
                    end
    Timex.compare(utc_0_shifted, utc_1, granularity)
  end
end
