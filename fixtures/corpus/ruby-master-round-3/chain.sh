#!/usr/bin/env bash
# usage: chain.sh APP... — run.sh for each app on r409, master and zjit in turn; apps live in .corpus/r3-APP.
# Pass RUNNER, PG, TEST_ARGS, PARALLEL_WORKERS through the environment (see run.sh and the doc's table).
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
for a in "$@"; do for l in r409 master zjit; do
  echo "$(date +%T) $a $l start"; "$here/run.sh" "$root/.corpus/r3-$a" "$l" "$a"; echo "$(date +%T) $a $l done"
done; done
