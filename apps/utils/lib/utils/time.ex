defmodule Utils.Time do
  alias Calendar.DateTime

  epoch = {{1970, 1, 1}, {0, 0, 0}}
  @epoch :calendar.datetime_to_gregorian_seconds(epoch)

  def from_unix_timestamp(timestamp) when is_integer(timestamp) do
    timestamp
    |> Kernel.+(@epoch)
    |> :calendar.gregorian_seconds_to_datetime
  end

  def to_unix_timestamp(datetime) when is_tuple(datetime) do
    datetime
    |> :calendar.datetime_to_gregorian_seconds
    |> Kernel.-(@epoch)
  end

  def from_local(datetime) when is_tuple(datetime) do
    datetime
    |> DateTime.from_erl!("Asia/Shanghai")
    |> DateTime.shift_zone!("Etc/UTC")
    |> DateTime.to_erl
  end
end
