defmodule Counter do
  @moduledoc """
  A counter every replica may increment, merged without coordination.

  Each replica keeps its own tally. `merge/2` is the part with a decision in it:
  it is called on whatever two states happen to meet, in whatever order, as
  many times as the network feels like.
  """

  @doc "A fresh state for the replica called `id`."
  def new(id), do: %{id: id, tallies: %{}}

  @doc "Add `n` to this replica's own tally."
  def increment(_state, _n), do: raise("not implemented")

  @doc "The total across all replicas."
  def value(_state), do: raise("not implemented")

  @doc "Combine two states seen by this replica."
  def merge(_a, _b), do: raise("not implemented")
end
