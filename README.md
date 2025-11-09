# Diffident

Generate structural diffs between two Elixir values.

## Examples

A simple example:

```elixir
left = %{name: "Alice", age: 30}
right = %{name: "Alice", age: 31, city: "NYC"}

Diffident.explain(left, right)
# Returns:
#   [
#    {:changed, [:age], 30, 31},
#    {:added, [:city], "NYC"}
#   ]
```

Here's one returning more complex structural changes:

```elixir
left = %{
  user: [
    %{id: 1, name: "Alice"},
    %{id: 2, name: "Bob"}
  ],
  meta: {:ok, %{count: 2}}
}

right = %{
  user: [
    %{id: 1, name: "Alice"},
    %{id: 2, name: "Robert"},
    %{id: 3, name: "Carol"}
  ],
  meta: {:ok, %{count: 3}}
}

Diffident.explain(left, right)
# Returns:
#   [
#     {:changed, [:user, {Access, :at, [1]}, :name], "Bob", "Robert"},
#     {:added, [:user, {Access, :at, [2]}], %{id: 3, name: "Carol"}},
#     {:changed, [:meta, {Access, :elem, [1]}, :count], 2, 3}
#.  ]
```

Note that the paths returned are serializable; rather than `Access` function calls, MFAs are returned, but you can convert them using `Diffident.to_access_compatible/1`:

```elixir
Diffident.to_access_compatible([:user, {Access, :at, [1]}, :name])
# Returns:
#   [:user, Access.at(1), :name]
```

Skip that intermediate step to use the path directly with `Diffident.get_in/2`:

```elixir
data = %{a: [1, %{b: 2}]}
path = [:a, {Access, :at, [1]}, :b]

Diffident.get_in(data, path)
# Returns:
#   2
```

They work with `Diffident.put_in/3`, too:

```elixir
data = {[%{x: 1}], 99}
path = [{Access, :elem, [0]}, {Access, :at, [0]}, :x]

updated = Diffident.put_in(data, path, 7)

Diffident.get_in(updated, path) == 7
# Returns:
#   true

updated == {[%{x: 7}], 99}
# Returns:
#   true
```

## Installation

```elixir
def deps do
  [
    {:diffident, "~> 0.1.0"}
  ]
end
```

## License

See `LICENSE`.
