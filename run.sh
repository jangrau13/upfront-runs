#!/bin/sh
# The candidate's counter, merged the way a network would deliver states:
# out of order, more than once, and between replicas that have been apart.
#
# The plan for this exam is written before the candidate speaks, so what these
# print is what the fixed questions get to be about. Each target says what it
# settles and, where it matters, what it cannot: `concurrent` passes under a
# merge that sums, and only `redelivery` tells a sum from a maximum.
#
# /work is root-owned, so the submission is compiled into /build and the probe
# script written there too.
set -eu

TARGET="${1:-converge}"

if [ "$TARGET" = "--list" ]; then
# An id and a sentence saying what running it shows. The sentence is what the
# examiner chooses on, so it says what the run can settle rather than naming it.
cat <<'LIST'
redelivery  Delivers the same replica state three times over and prints the total after each. The network delivers duplicates, so a merge that sums rather than taking a maximum grows a total nobody incremented.
reorder     Merges three replica states in five different orders and compares the totals. Whether two replicas that saw the same states in different orders can disagree forever.
concurrent  Two replicas increment while they cannot see each other, then exchange states. Both increments have to survive — but a merge that sums survives this too, so it is worth reading beside redelivery.
converge    Three replicas, three rounds of gossip, reordered and with states delivered twice. Whether all three end on the same total and whether that total is the one that was incremented.
LIST
  exit 0
fi

case "$TARGET" in
  redelivery|reorder|concurrent|converge) ;;
  *) echo "no such target: $TARGET"; echo "run.sh --list names all four"; exit 2 ;;
esac

# $TMPDIR is set to /build/tmp by the image; the tmpfs is mounted fresh for
# each session, so the directory itself has to be made here rather than baked in.
mkdir -p "${TMPDIR:-/build/tmp}"
W=/build/viva-run
rm -rf "$W"
mkdir -p "$W/ebin"

if [ ! -f /work/counter.ex ]; then
  echo "the submission has no counter.ex at its root"
  exit 2
fi

# Compiled rather than required, so that a counter split across modules still
# runs and so that a compile error is reported as one.
cd /work
elixirc -o "$W/ebin" *.ex 2>&1 || exit 1

cat > "$W/probe.exs" <<'EX'
# What the merge does when the network is honest about itself.
#
# Nothing here looks inside a state: a candidate may hold their tallies however
# they like, and every answer is read back through Counter.value/1.
defmodule Probe do
  def replica(id, n), do: Counter.new(id) |> Counter.increment(n)
  def total(state), do: Counter.value(state)
  def row(label, n), do: IO.puts("  " <> String.pad_trailing(label, 26) <> to_string(n))

  def redelivery do
    a = replica(:a, 3)
    b = replica(:b, 4)
    once = Counter.merge(a, b)
    twice = Counter.merge(once, b)
    thrice = Counter.merge(twice, b)

    IO.puts("a incremented by 3, b by 4")
    row("a on its own:", total(a))
    row("after b's state arrives:", total(once))
    row("after it arrives again:", total(twice))
    row("and once more:", total(thrice))
    IO.puts("")

    if total(once) == total(twice) and total(twice) == total(thrice) do
      IO.puts("the same state delivered three times counts once")
    else
      IO.puts(
        "A DUPLICATE DELIVERY MOVED THE TOTAL — #{total(once)} became #{total(thrice)} " <>
          "with nothing incremented in between"
      )
    end
  end

  def reorder do
    a = replica(:a, 3)
    b = replica(:b, 4)
    c = replica(:c, 5)

    orders = [
      {"a <- b <- c", Counter.merge(Counter.merge(a, b), c)},
      {"a <- c <- b", Counter.merge(Counter.merge(a, c), b)},
      {"b <- c <- a", Counter.merge(Counter.merge(b, c), a)},
      {"c <- a <- b", Counter.merge(Counter.merge(c, a), b)},
      {"a <- (b <- c)", Counter.merge(a, Counter.merge(b, c))}
    ]

    IO.puts("three replicas holding 3, 4 and 5, merged every way round:")
    Enum.each(orders, fn {label, state} ->
      IO.puts("  #{String.pad_trailing(label, 14)} #{total(state)}")
    end)
    IO.puts("")

    totals = Enum.map(orders, fn {_label, state} -> total(state) end)

    if length(Enum.uniq(totals)) == 1 do
      IO.puts("every order lands on the same total")
    else
      # Joined rather than inspected: a list of small integers is a charlist to
      # `inspect`, and the examiner would be shown punctuation instead of totals.
      IO.puts(
        "ORDER MATTERS — the same three states give #{Enum.join(Enum.uniq(totals), ", ")} " <>
          "depending on who arrives first, so two replicas can disagree forever"
      )
    end
  end

  def concurrent do
    a = replica(:a, 3)
    b = replica(:b, 4)

    a_after = Counter.merge(a, b)
    b_after = Counter.merge(b, a)

    IO.puts("a incremented by 3 and b by 4 while they could not see each other")
    IO.puts("  a, once b's state arrives: #{total(a_after)}")
    IO.puts("  b, once a's state arrives: #{total(b_after)}")
    IO.puts("")

    cond do
      total(a_after) != total(b_after) ->
        IO.puts("THE TWO DISAGREE — #{total(a_after)} against #{total(b_after)}, " <>
                  "from the same two states")

      total(a_after) == 7 ->
        IO.puts("both increments survived: 7. A merge that sums passes this too, " <>
                  "so run redelivery before reading anything into it")

      true ->
        IO.puts("AN INCREMENT WAS LOST — 3 and 4 were concurrent and the merge " <>
                  "settled on #{total(a_after)}")
    end
  end

  def converge do
    a0 = replica(:a, 3)
    b0 = replica(:b, 4)
    c0 = replica(:c, 5)

    # Each replica hears from one neighbour.
    a1 = Counter.merge(a0, b0)
    b1 = Counter.merge(b0, c0)
    c1 = Counter.merge(c0, a0)

    # And then out of order, and from states already delivered once.
    a2 = a1 |> Counter.merge(c1) |> Counter.merge(b0)
    b2 = b1 |> Counter.merge(a1) |> Counter.merge(c1)
    c2 = c1 |> Counter.merge(b1) |> Counter.merge(a1)

    # A last round, so nothing is left unseen by anyone.
    a3 = Counter.merge(a2, b2)
    b3 = Counter.merge(b2, c2)
    c3 = Counter.merge(c2, a2)

    IO.puts("a incremented by 3, b by 4, c by 5 — every replica should end on 12")
    IO.puts("after three rounds of gossip, reordered and with duplicates:")
    IO.puts("  a: #{total(a3)}")
    IO.puts("  b: #{total(b3)}")
    IO.puts("  c: #{total(c3)}")
    IO.puts("")

    totals = [total(a3), total(b3), total(c3)]

    cond do
      length(Enum.uniq(totals)) > 1 ->
        IO.puts("THEY NEVER SETTLED — #{Enum.join(totals, ", ")}, " <>
                  "with every state seen by everyone")

      hd(totals) == 12 ->
        IO.puts("all three settled on 12, which is what was incremented")

      true ->
        IO.puts("all three settled on #{hd(totals)} INSTEAD OF 12 — they agree, " <>
                  "on a number nobody incremented to")
    end
  end
end

case System.argv() do
  ["redelivery"] -> Probe.redelivery()
  ["reorder"] -> Probe.reorder()
  ["concurrent"] -> Probe.concurrent()
  ["converge"] -> Probe.converge()
end
EX

elixir -pa "$W/ebin" "$W/probe.exs" "$TARGET"
