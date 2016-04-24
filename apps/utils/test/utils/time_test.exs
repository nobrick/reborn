defmodule Utils.TimeTest do
  use ExUnit.Case
  alias Utils.Time

  @unix_timestamp 1461391431
  @erl_datetime {{2016, 4, 23}, {6, 3, 51}}

  test "from_unix_timestamp/1" do
    assert Time.from_unix_timestamp(@unix_timestamp) == @erl_datetime
  end

  test "to_unix_timestamp/1" do
    assert Time.to_unix_timestamp(@erl_datetime) == @unix_timestamp
  end
end
