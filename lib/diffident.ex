defmodule Diffident do
  @moduledoc """
  Structured diffs between two Elixir values.

  Returns a serializable list of tagged tuples describing the differences between two values.

  Examples

      iex> Diffident.explain([:x, :y], [:x, :z, :w])
      [
        {:changed, [{Access, :at, [1]}], :y, :z},
        {:added, [{Access, :at, [2]}], :w}
      ]

      iex> result = Diffident.explain([a: 1, b: 2], [a: 1, b: 3, c: 4])
      iex> length(result)
      2
      iex> {:changed, [:b], 2, 3} in result
      true
      iex> {:added, [:c], 4} in result
      true

      iex> result = Diffident.explain(%{a: 1, b: [1,2]}, %{a: 2, b: [1,3], c: 9})
      iex> length(result)
      3
      iex> {:changed, [:a], 1, 2} in result
      true
      iex> {:changed, [:b, {Access, :at, [1]}], 2, 3} in result
      true
      iex> {:added, [:c], 9} in result
      true
  """

  @type access_mfa :: {Access, atom(), list(any())}
  @type path_entry :: access_mfa() | any()
  @type path :: list(path_entry())

  @doc """
  Returns a list of tagged tuples describing differences between `left` and `right`.
  No output (empty list) means the values are equal by structural comparison.

  ## Formats

  - `{:added, path, value}` - a new key/element was added
  - `{:removed, path, value}` - a key/element was removed
  - `{:changed, path, old_value, new_value}` - a value changed
  - `{:type_changed, path, old_value, new_value}` - the type of value changed
  - `{:tuple_size_changed, path, old_size, new_size}` - tuple size changed

  The `path` is a list suitable for use with `get_in/2` and `put_in/3`.
  List indices use `{Access, :at, [index]}` and tuple indices use `{Access, :elem, [index]}`.
  """
  @spec explain(any(), any()) :: [
          {:added, path(), any()}
          | {:removed, path(), any()}
          | {:changed, path(), any(), any()}
          | {:type_changed, path(), any(), any()}
          | {:tuple_size_changed, path(), non_neg_integer(), non_neg_integer()}
        ]
  def explain(left, right) do
    diff(left, right, [])
  end

  @doc """
  Gets a value from `data` using a path in the format returned by `explain/2`.
  """
  @spec get_in(any(), path()) :: any()
  def get_in(data, path) do
    resolved_path = to_access_compatible(path)
    Kernel.get_in(data, resolved_path)
  end

  @doc """
  Puts a value into `data` at the location specified by a path in the format
  returned by `explain/2`, returning the updated data structure.
  """
  @spec put_in(any(), path(), any()) :: any()
  def put_in(data, path, value) do
    resolved_path = to_access_compatible(path)
    Kernel.put_in(data, resolved_path, value)
  end

  @doc """
  Converts a path from `explain/2` to a format usable with `get_in/2` and `put_in/3`.

  Converts MFA tuples like `{Access, :at, [1]}` to actual function calls.

  ## Examples

      iex> Diffident.to_access_compatible([:a, {Access, :at, [1]}])
      [:a, Access.at(1)]

      iex> Diffident.to_access_compatible([{Access, :elem, [0]}, :field])
      [Access.elem(0), :field]
  """
  @spec to_access_compatible(path()) :: [any()]
  def to_access_compatible(path) do
    Enum.map(path, fn
      {mod, fun, args} -> apply(mod, fun, args)
      other -> other
    end)
  end

  ## Core dispatcher

  defp diff(x, y, _path) when x === y, do: []

  # Structs: compare type first, then fields
  defp diff(%_{} = x, %_{} = y, path) do
    xtype = x.__struct__
    ytype = y.__struct__

    if xtype != ytype do
      [{:type_changed, Enum.reverse(path), xtype, ytype}]
    else
      diff(Map.from_struct(x), Map.from_struct(y), path)
    end
  end

  # Maps
  defp diff(%{} = x, %{} = y, path) do
    x_keys = Map.keys(x) |> MapSet.new()
    y_keys = Map.keys(y) |> MapSet.new()

    removed =
      MapSet.difference(x_keys, y_keys)
      |> Enum.map(fn k ->
        {:removed, Enum.reverse([k | path]), Map.fetch!(x, k)}
      end)

    added =
      MapSet.difference(y_keys, x_keys)
      |> Enum.map(fn k ->
        {:added, Enum.reverse([k | path]), Map.fetch!(y, k)}
      end)

    changed =
      MapSet.intersection(x_keys, y_keys)
      |> Enum.flat_map(fn k ->
        diff(Map.fetch!(x, k), Map.fetch!(y, k), [k | path])
      end)

    removed ++ added ++ changed
  end

  # Keyword lists (prefer key-based comparison if keys are unique)
  defp diff(x, y, path) when is_list(x) and is_list(y) do
    if Keyword.keyword?(x) and Keyword.keyword?(y) do
      if unique_keys?(x) and unique_keys?(y) do
        diff(Map.new(x), Map.new(y), path)
      else
        # fall back to index-by-index comparison
        diff_list_by_index(x, y, path)
      end
    else
      diff_list_by_index(x, y, path)
    end
  end

  # Lists (non-keyword)
  defp diff(x, y, path) when is_list(x) and is_list(y) do
    diff_list_by_index(x, y, path)
  end

  # Tuples: compare arity then elements
  defp diff(x, y, path) when is_tuple(x) and is_tuple(y) do
    if tuple_size(x) != tuple_size(y) do
      [{:tuple_size_changed, Enum.reverse(path), tuple_size(x), tuple_size(y)}]
    else
      x_list = Tuple.to_list(x)

      Enum.with_index(x_list)
      |> Enum.flat_map(fn {xe, i} ->
        diff(xe, elem(y, i), [{Access, :elem, [i]} | path])
      end)
    end
  end

  # Different types entirely
  defp diff(x, y, path) do
    if same_type?(x, y) do
      # Primitive/value change
      [{:changed, Enum.reverse(path), x, y}]
    else
      [{:type_changed, Enum.reverse(path), x, y}]
    end
  end

  ## Helpers

  defp diff_list_by_index(x, y, path) do
    max = max(length(x), length(y))

    0..(max - 1)
    |> Enum.flat_map(fn i ->
      xi = Enum.fetch(x, i)
      yi = Enum.fetch(y, i)

      case {xi, yi} do
        {:error, {:ok, v}} ->
          [{:added, Enum.reverse([{Access, :at, [i]} | path]), v}]

        {{:ok, v}, :error} ->
          [{:removed, Enum.reverse([{Access, :at, [i]} | path]), v}]

        {{:ok, xv}, {:ok, yv}} ->
          diff(xv, yv, [{Access, :at, [i]} | path])
      end
    end)
  end

  defp same_type?(a, b), do: type_tag(a) == type_tag(b)

  defp type_tag(%_{} = s), do: {:struct, s.__struct__}
  defp type_tag(v) when is_map(v), do: :map

  defp type_tag(v) when is_list(v) do
    if Keyword.keyword?(v), do: :keyword, else: :list
  end

  defp type_tag(v) when is_tuple(v), do: :tuple
  defp type_tag(v) when is_integer(v), do: :integer
  defp type_tag(v) when is_float(v), do: :float
  defp type_tag(v) when is_binary(v), do: :binary
  defp type_tag(v) when is_atom(v), do: :atom
  defp type_tag(v) when is_boolean(v), do: :boolean
  defp type_tag(_), do: :other

  defp unique_keys?(kw) do
    keys = Keyword.keys(kw)
    MapSet.size(MapSet.new(keys)) == length(keys)
  end
end
