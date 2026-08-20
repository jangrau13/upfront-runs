#!/bin/sh
# Whether the submission builds, which is what a patch probe rests on: a diff
# the examiner wrote and that does not compile has to come back as the
# examiner's mistake, before anything is run and before any of it is put to the
# candidate.
#
# elixirc writes .beam files into the working directory and /work is
# root-owned, so -o points them at /build instead. There is no `mix deps.get`
# anywhere here: the container has no network, and this assignment is one file.
set -eu

# $TMPDIR is set to /build/tmp by the image; the tmpfs is mounted fresh for
# each session, so the directory itself has to be made here rather than baked in.
mkdir -p "${TMPDIR:-/build/tmp}"
OUT=/build/viva-ebin
rm -rf "$OUT"
mkdir -p "$OUT"

cd /work
if [ ! -f counter.ex ]; then
  echo "the submission has no counter.ex at its root"
  exit 2
fi

# Every module at the root, not only counter.ex: a submission that split its
# helpers out is still a submission that has to build.
#
# No --warnings-as-errors. Elixir warns about a great deal that compiles and
# runs — an unused variable, a deprecated call — and elixirc's exit status
# already draws the line this script is here to draw: non-zero for an error
# alone. A patch refused over a warning would be refused for nothing.
elixirc -o "$OUT" *.ex 2>&1
