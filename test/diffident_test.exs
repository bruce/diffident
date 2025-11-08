defmodule DiffidentTest do
  use ExUnit.Case
  doctest Diffident

  defmodule S1 do
    defstruct [:a]
  end

  defmodule S2 do
    defstruct [:a]
  end

  describe "explain/2" do
    test "returns [] for equal values" do
      assert Diffident.explain(1, 1) == []
      assert Diffident.explain([1, 2], [1, 2]) == []
      assert Diffident.explain(%{a: 1}, %{a: 1}) == []
    end

    test "detects added, removed, and changed map keys" do
      left = %{a: 1, b: 2}
      right = %{a: 2, c: 3}

      assert Enum.sort(Diffident.explain(left, right)) ==
               Enum.sort([
                 {:changed, [:a], 1, 2},
                 {:removed, [:b], 2},
                 {:added, [:c], 3}
               ])
    end

    test "detects added, removed, and changed keyword list keys" do
      left = [a: 1, b: 2]
      right = [a: 2, c: 3]

      assert Enum.sort(Diffident.explain(left, right)) ==
               Enum.sort([
                 {:changed, [:a], 1, 2},
                 {:removed, [:b], 2},
                 {:added, [:c], 3}
               ])
    end

    test "detects added, removed, and changed list elements" do
      left = [1, 2]
      right = [1, 3, 4]

      assert Enum.sort(Diffident.explain(left, right)) ==
               Enum.sort([
                 {:changed, [{Access, :at, [1]}], 2, 3},
                 {:added, [{Access, :at, [2]}], 4}
               ])
    end

    test "detects tuple size and element changes" do
      left = {1, 2}
      right = {1, 3, 4}

      assert Diffident.explain(left, right) == [
               {:tuple_size_changed, [], 2, 3}
             ]

      left2 = {1, 2}
      right2 = {1, 3}

      assert Diffident.explain(left2, right2) == [
               {:changed, [{Access, :elem, [1]}], 2, 3}
             ]
    end

    test "detects struct type change and field change" do
      s1 = %S1{a: 1}
      s2 = %S2{a: 1}

      assert Diffident.explain(s1, s2) == [
               {:type_changed, [], S1, S2}
             ]

      s1b = %S1{a: 1}
      s1c = %S1{a: 2}

      assert Diffident.explain(s1b, s1c) == [
               {:changed, [:a], 1, 2}
             ]
    end

    test "detects primitive type changes" do
      assert Diffident.explain(1, "1") == [
               {:type_changed, [], 1, "1"}
             ]

      assert Diffident.explain(:a, 1) == [
               {:type_changed, [], :a, 1}
             ]

      assert Diffident.explain(%S1{a: 1}, %S2{a: 2}) == [
               {:type_changed, [], S1, S2}
             ]
    end
  end

  describe "to_access_compatible/1" do
    test "converts MFA tuples in path to Access calls" do
      path = [:a, {Access, :at, [1]}]
      assert Diffident.to_access_compatible(path) == [:a, Access.at(1)]

      path2 = [{Access, :elem, [0]}, :field]
      assert Diffident.to_access_compatible(path2) == [Access.elem(0), :field]
    end
  end

  describe "get_in/2 and put_in/3 compatibility" do
    test "get_in/2 works with resolved paths" do
      data = %{a: [1, %{b: 2}]}
      path = [:a, {Access, :at, [1]}, :b]
      assert Diffident.get_in(data, path) == 2
    end

    test "put_in/3 works with resolved paths" do
      data = %{a: [1, %{b: 2}]}
      path = [:a, {Access, :at, [1]}, :b]
      updated = Diffident.put_in(data, path, 42)
      assert Diffident.get_in(updated, path) == 42
      assert updated == %{a: [1, %{b: 42}]}
    end

    test "get_in/2 works with tuple paths" do
      data = {[%{x: 1}], 99}
      path = [{Access, :elem, [0]}, {Access, :at, [0]}, :x]
      assert Diffident.get_in(data, path) == 1
    end

    test "put_in/3 works with tuple paths" do
      data = {[%{x: 1}], 99}
      path = [{Access, :elem, [0]}, {Access, :at, [0]}, :x]
      updated = Diffident.put_in(data, path, 7)
      assert Diffident.get_in(updated, path) == 7
      assert updated == {[%{x: 7}], 99}
    end
  end
end
