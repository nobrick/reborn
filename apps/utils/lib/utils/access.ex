defmodule Utils.Access do
  def put_present(map, key_or_keys, test, lazy \\ & &1)

  def put_present(map, key_or_keys, test, value)
      when not is_function(value) do
    put_present(map, key_or_keys, test, fn _ -> value end)
  end

  def put_present(map, key, test, lazy)
      when is_atom(key) and is_function(lazy, 1) do
    case test do
      nil -> map
      _   -> Map.put(map, key, lazy.(test))
    end
  end

  def put_present(map, keys, test, lazy)
      when is_list(keys) and is_function(lazy, 1) do
    case test do
      nil -> map
      _   -> put_in(map, keys, lazy.(test))
    end
  end
end
