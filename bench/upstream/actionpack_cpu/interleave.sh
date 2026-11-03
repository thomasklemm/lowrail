#!/usr/bin/env bash
# Interleaved ruby-bench wall time for bet P1: per round, each variant in a
# rotated order, on each app and mode, ruby-bench's default harness.
# Variants are Rails worktrees; RAILS_LINK is the symlink the ruby-bench
# Gemfiles point at (path: gems), switched before each run.
#   interleave.sh RUBY_BENCH_DIR RAILS_LINK OUT_DIR ROUNDS APPS VARIANT=WORKTREE...
set -euo pipefail
rb=$1; link=$2; out=$3; rounds=$4; apps=$5; shift 5
variants=("$@")
mkdir -p "$out"
n=${#variants[@]}
for round in $(seq 1 "$rounds"); do
  for k in $(seq 0 $((n - 1))); do
    spec=${variants[$(( (k + round - 1) % n ))]}
    name=${spec%%=*}; tree=${spec#*=}
    ln -sfn "$tree" "$link"
    for app in ${apps//,/ }; do
      for mode in interp yjit; do
        flag=""; [ "$mode" = yjit ] && flag="--yjit"
        log="$out/$app-$mode-$name-r$round.log"
        (cd "$rb" && WARMUP_ITRS=${WARMUP_ITRS:-10} MIN_BENCH_ITRS=${MIN_BENCH_ITRS:-20} MIN_BENCH_TIME=0 \
          OUT_CSV_PATH=/tmp/interleave.csv ruby $flag "benchmarks/$app/benchmark.rb" > "$log" 2>&1)
        echo "$(date +%T) round $round $name $app $mode: $(tail -n1 "$log")"
      done
    done
  done
done
