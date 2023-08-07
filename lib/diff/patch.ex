defmodule ExAudit.Patch do
  @doc """
  Applies the patch to the given term
  """
  def patch(_, {:primitive_change, _, value}), do: value
  def patch(value, :not_changed), do: value
  def patch(nil, changes) when is_list(changes), do: patch([], changes)

  def patch(list, changes) when is_list(list) and is_list(changes) do
    changes
    |> Enum.reverse()
    |> Enum.reduce(list, fn
      {:added_to_list, i, el}, list -> List.insert_at(list, i, el)
      {:removed_from_list, i, _}, list -> List.delete_at(list, i)
      {:changed_in_list, i, change}, list -> List.update_at(list, i, &patch(&1, change))
    end)
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
      {key, {:changed, changes}}, map -> Map.put(map, key, patch(map, changes))
    end)
  end
end
