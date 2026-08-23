defmodule Counter do
  def new(id), do: %{id: id, tallies: %{}}

  def increment(state, n) do
    %{state | tallies: Map.update(state.tallies, state.id, n, &(&1 + n))}
  end

  def value(state), do: state.tallies |> Map.values() |> Enum.sum()

  def merge(_a, _b), do: raise("not implemented")
end
