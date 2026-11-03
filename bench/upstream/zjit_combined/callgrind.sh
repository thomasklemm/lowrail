#!/usr/bin/env bash
# Callgrind Ir under ZJIT on ruby-bench railsbench and lobsters, Rails main
# ($RB_WITH) against the same commit with our merged PRs reverted ($RB_WITHOUT).
#   bench/upstream/zjit_combined/callgrind.sh OUT ROUNDS
# Per round and app: with-A, without-A, without-B, with-B in an order rotated by
# round, sequential (parallel lobsters copies share tmp/cache). Each process:
# WARMUP_ITRS warmup, then an empty and a MEASURE_ITRS window (harness.rb),
# GC excluded (CG_NO_GC=1). $RUBY_BIN is the master build, $CG_EXT the directory
# with lowrail_callgrind.so built against it.
set -euo pipefail
out=$1 rounds=$2
here=$(cd "$(dirname "$0")" && pwd)
: "${RB_WITH:=/home/user/workspace/rb-main}" "${RB_WITHOUT:=/home/user/workspace/rb-rev}"
: "${RUBY_BIN:?}" "${CG_EXT:?}" "${MODE_FLAGS:=--zjit}"
export PATH="$RUBY_BIN:$PATH" WARMUP_ITRS=${WARMUP_ITRS:-15} MEASURE_ITRS=${MEASURE_ITRS:-3} CG_NO_GC=1
unset GEM_HOME GEM_PATH RUBYOPT
mkdir -p "$out"
variants=(with-A without-A without-B with-B)
for round in $(seq 1 "$rounds"); do
  for app in railsbench lobsters; do
    for i in 0 1 2 3; do
      v=${variants[$(((i + round) % 4))]}
      dir=$RB_WITH; [[ $v == without-* ]] && dir=$RB_WITHOUT
      name=$app-$v-r$round
      [[ -f $out/$name.cg.2 ]] && continue
      (cd "$dir" && valgrind --tool=callgrind --instr-atstart=no --smc-check=all-non-file \
        --callgrind-out-file="$out/$name.cg" --log-file="$out/$name.vg.log" \
        "$RUBY_BIN/ruby" $MODE_FLAGS -I"$CG_EXT" -I"$here" "benchmarks/$app/benchmark.rb" > "$out/$name.log" 2>&1) \
        || echo "FAILED $name"
      grep -q 'brk segment overflow' "$out/$name.vg.log" && echo "BRK $name"
      echo "$(date -u +%H:%M:%S) $name"
    done
  done
done
