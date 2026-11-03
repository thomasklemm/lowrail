#!/usr/bin/env bash
# Interleaved ruby-bench wall time for docs/upstream/combined-effect.md.
#   bench/upstream/combined_effect/walltime.sh OUT ROUNDS
# Two ruby-bench checkouts (byroot/ruby-bench bf1afb2 plus
# bench/upstream/index_with_ruby_bench/ruby-bench.patch) differ only in the
# Rails path: $RB_WITH points at Rails main, $RB_WITHOUT at the same commit with
# the PRs reverted. Per round, every app and mode runs four processes, with-A,
# without-A, without-B and with-B, in an order rotated by round, pinned to one
# CPU. Each process: WARMUP_ITRS warmup and BENCH_ITRS timed iterations.
set -euo pipefail
out=$1 rounds=$2
harness=$(cd "$(dirname "$0")" && pwd)
: "${RB_WITH:=/home/user/workspace/rb-main}" "${RB_WITHOUT:=/home/user/workspace/rb-rev}" "${CPU:=2}"
export WARMUP_ITRS=${WARMUP_ITRS:-10} BENCH_ITRS=${BENCH_ITRS:-20}
mkdir -p "$out"
variants=(with-A without-A without-B with-B)
for round in $(seq 1 "$rounds"); do
  for app in railsbench lobsters; do
    for mode in interp yjit; do
      for i in 0 1 2 3; do
        v=${variants[$(((i + round) % 4))]}
        dir=$RB_WITH; [[ $v == without-* ]] && dir=$RB_WITHOUT
        name=$app-$mode-$v-r$round
        [[ -f $out/$name.json ]] && continue
        flags=(); [[ $mode == yjit ]] && flags=(--yjit)
        (cd "$dir" && CE_OUT="$out/$name.json" taskset -c "$CPU" ruby "${flags[@]}" -I"$harness" \
          "benchmarks/$app/benchmark.rb" > "$out/$name.log" 2>&1)
        echo "$(date -u +%H:%M:%S) $name"
      done
    done
  done
done
