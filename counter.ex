defmodule Counter do
  def new(id), do: %{id: id, tallies: %{}}

  def increment(state, n) do
    %{state | tallies: Map.update(state.tallies, state.id, n, &(&1 + n))}
  end

  def value(state), do: state.tallies |> Map.values() |> Enum.sum()

  # Combine the two replicas' tallies by adding them together, so no
  # increment from either side is lost.
  def merge(a, b) do
    %{a | tallies: Map.merge(a.tallies, b.tallies, fn _id, x, y -> x + y end)}
  end
end
