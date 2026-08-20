# Count without coordinating (example assignment)

Every replica may increment the counter. They gossip their state to each other
whenever they feel like it, in whatever order, more than once.

Your problem is `counter.ex`, and three functions in it.

## What to do

1. **`increment(state, n)`** — add to this replica's own tally.
2. **`value(state)`** — the total across all replicas.
3. **`merge(a, b)`** — combine two states.

## What you are marked on

Whether you can defend `merge/2` in a viva. Every question is written before
you speak, and the examiner can run your code first.
