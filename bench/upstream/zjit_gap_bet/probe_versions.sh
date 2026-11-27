#!/usr/bin/env bash
# How many ZJIT versions each ISEQ gets in one ruby-bench run (one log line per compiled version), e.g. why
# fetch_value_at!'s &:value! still falls back on headline6 under shipit (HANDOFF.md, Opus follow-up).
#   probe_versions.sh BUILD BENCH OUTDIR [extra ruby flags...]
set -uo pipefail
build=$1 bench=$2 out=$3; shift 3
mkdir -p "$out" "$HOME/w/rbc"
copy=$HOME/w/rbc/probe-$bench
[ -d "$copy" ] || cp -a "$HOME/w/ruby-bench" "$copy"
cp ~/workspace/repo/bench/upstream/zjit_yjit_gap_harness.rb "$copy/harness/gap.rb"
cd "$copy"
unset RUBYOPT
HARNESS=gap GAP_MODE=stats WARMUP_ITRS=${WARMUP_ITRS:-100} MIN_BENCH_ITRS=10 RUBY_GC_HEAP_INIT_BYTES=33554432 \
  GAP_JSON=$out/$bench-$build.json BUNDLE_GEMFILE=$copy/benchmarks/$bench/Gemfile.main \
  "$HOME/rubies/$build/bin/ruby" --zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024 --zjit-stats-quiet \
  --zjit-log-compiled-iseqs="$out/$bench-$build.iseqs" "$@" "benchmarks/$bench/benchmark.rb" > "$out/$bench-$build.log" 2>&1
echo "exit $?"
