#!/usr/bin/env bash
# Profile ruby-bench railsbench, lobsters and shipit (interpreter and YJIT)
# with harness_prof.rb. Usage: profile.sh RUBY_BENCH_DIR OUT_DIR [ITRS]
set -euo pipefail
rb=$1; out=$2; itrs=${3:-10}
mkdir -p "$out"
cp "$(dirname "$0")/harness_prof.rb" "$rb/harness/lowrail_prof.rb"
cd "$rb"
for app in railsbench lobsters shipit; do
  for mode in interp yjit; do
    flag=""; [ "$mode" = yjit ] && flag="--yjit"
    PROF_MODE=wall PROF_INTERVAL=${PROF_INTERVAL:-200} PROF_OUT="$out/$app-$mode.dump" WARMUP_ITRS=${WARMUP_ITRS:-10} \
      PROF_ITRS=$itrs HARNESS=lowrail_prof ruby $flag "benchmarks/$app/benchmark.rb" > "$out/$app-$mode.log" 2>&1 &
  done
done
wait
tail -n1 "$out"/*.log
