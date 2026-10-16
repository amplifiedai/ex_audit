defmodule PatchTest do
  use ExUnit.Case

  alias ExAudit.{Diff, Patch}
  doctest Patch

  test "should apply primitive changes" do
    assert_patching(:foo, :bar)
  end

  test "should cope with :not_changed" do
    assert_patching(:foo, :foo)
  end

  test "should apply patches to lists" do
    assert_patching([1, 2, 3], [1, 2, 4, 5])
    assert_patching([1, 2, 3], [])
  end

  test "should apply patches to maps" do
    assert_patching(%{a: 1, b: 2}, %{a: 3, b: 4})
    assert_patching(%{}, %{foo: 3})
    assert_patching(%{foo: 42}, %{})
  end

  test "should apply patches to complex structures" do
    a = [%{foo: [1, 2, 3]}]
    b = [%{foo: [1, 2, 3, 4]}]

    assert_patching(a, b)
  end

  test "should undo a patch that added or removed several list items" do
    assert_patching([1], [1, 2, 3])
    assert_patching([1, 2, 3], [1])
    assert_patching(["a", "b"], ["c", "a", "b", "d"])
    assert_patching([%{foo: [1]}], [%{foo: [1, 2, 3]}, %{bar: 1}, %{baz: 2}])
  end

  test "should apply and undo the patch between any two short lists" do
    lists = for length <- 0..4, list <- lists_of(length, [:a, :b, :c]), do: list

    for a <- lists, b <- lists do
      assert_patching(a, b)
    end
  end

  test "should build each changed map from nothing" do
    assert %{a: %{x: 1}, b: %{y: 2}} ==
             Patch.patch(nil, %{
               a: {:changed, %{x: {:added, 1}}},
               b: {:changed, %{y: {:added, 2}}}
             })
  end

  defp lists_of(0, _items), do: [[]]

  defp lists_of(length, items),
    do: for(item <- items, rest <- lists_of(length - 1, items), do: [item | rest])

  defp assert_patching(a, b) do
    patch = Diff.diff(a, b)
    assert b == Patch.patch(a, patch)
    assert a == Patch.patch(b, Diff.reverse(patch))
  end
end
