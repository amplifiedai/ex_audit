defmodule ExAudit.Patch do
  @doc """
  Applies the patch to the given term
  """
  def patch(_, {:primitive_change, _, value}), do: value
  def patch(value, :not_changed), do: value
  def patch(nil, changes) when is_list(changes), do: patch([], changes)

  # A list diff compares two lists position by position, so a change or a removal names a position
  # in the list being patched, and an addition names a position in the result. The patch is applied
  # in one walk of the list, which is right whatever order the changes come in (a reversed patch
  # lists them in the opposite order), and takes time in proportion to the list's length rather
  # than to its length times the number of changes.
  def patch(list, changes) when is_list(list) and is_list(changes) do
    {additions, others} = Enum.split_with(changes, &match?({:added_to_list, _, _}, &1))
    by_position = Map.new(others, fn {_type, i, _} = change -> {i, change} end)

    list
    |> Enum.with_index()
    |> Enum.flat_map(fn {el, i} -> patch_element(el, Map.get(by_position, i)) end)
    |> insert(Enum.sort_by(additions, fn {:added_to_list, i, _} -> i end), 0, [])
  end

  def patch(map, changes) when is_map(map) and is_map(changes) do
    Enum.reduce(changes, map, fn
      {key, {:added, value}}, map -> Map.put(map, key, value)
      {key, {:removed, _}}, map -> Map.delete(map, key)
      {key, {:changed, changes}}, map -> Map.update(map, key, nil, &patch(&1, changes))
    end)
  end

  def patch(nil, changes) when is_map(changes) do
    Enum.reduce(changes, %{}, fn
      {key, {:added, value}}, map -> Map.put(map, key, value)
      {key, {:removed, _}}, map -> Map.delete(map, key)
      {key, {:changed, changes}}, map -> Map.put(map, key, patch(nil, changes))
    end)
  end

  def patch(term, _), do: term

  defp patch_element(el, nil), do: [el]
  defp patch_element(_el, {:removed_from_list, _i, _}), do: []
  defp patch_element(el, {:changed_in_list, _i, change}), do: [patch(el, change)]

  # Puts each addition at its position in the result, and the remaining elements around them.
  defp insert(rest, [], _position, acc), do: Enum.reverse(acc, rest)

  defp insert(rest, [{:added_to_list, position, el} | additions], position, acc),
    do: insert(rest, additions, position + 1, [el | acc])

  defp insert([el | rest], additions, position, acc),
    do: insert(rest, additions, position + 1, [el | acc])

  defp insert([], [{:added_to_list, _i, el} | additions], position, acc),
    do: insert([], additions, position + 1, [el | acc])
end
