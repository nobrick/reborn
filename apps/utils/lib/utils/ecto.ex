defmodule Utils.Ecto do
  import Ecto.Query, only: [from: 2]

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
