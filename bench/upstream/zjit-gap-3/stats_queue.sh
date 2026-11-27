#!/usr/bin/env bash
# JIT counters and ZJIT fallback/exit traces for docs/upstream/zjit-gap-census-3.md, ruby-bench on Rails main.
#   stats_queue.sh OUT JOB...   JOB = build:kind:bench
#   build: a prefix under ~/rubies; kind: zjit (--zjit-stats-quiet), yjit (--yjit-stats=quiet),
#   trace (ZJIT, --zjit-trace-exits and --zjit-trace-fallbacks sampled 1 in 20, whole process).
# 100 warmup and 10 counted iterations (zjit_yjit_gap_harness.rb, GAP_MODE=stats), fixed heap, own ruby-bench copy.
set -uo pipefail
out=$1; shift
Z=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024)
export HARNESS=gap GAP_MODE=stats WARMUP_ITRS=${WARMUP_ITRS:-100} MIN_BENCH_ITRS=10 RUBY_GC_HEAP_INIT_BYTES=33554432
unset RUBYOPT
mkdir -p "$out" "$HOME/w/rbc"
for job in "$@"; do
  IFS=: read -r build kind bench <<< "$job"
  name=$bench-$build-$kind
  [ -f "$out/$name.json" ] && { echo "skip $job"; continue; }
  copy=$HOME/w/rbc/stats-$name
  [ -d "$copy" ] || cp -a "${RUBY_BENCH_DIR:-$HOME/w/ruby-bench}" "$copy"
  case $kind in
    zjit) flags=("${Z[@]}" --zjit-stats-quiet) ;;
    yjit) flags=(--yjit --yjit-stats=quiet) ;;
    trace) flags=("${Z[@]}" --zjit-stats-quiet --zjit-trace-exits --zjit-trace-exits-sample-rate=20 --zjit-trace-fallbacks-sample-rate=20) ;;
  esac
  s=$(date +%s)
  (cd "$copy" && GAP_JSON=$out/$name.json BUNDLE_GEMFILE=$copy/benchmarks/$bench/Gemfile.main \
    exec "$HOME/rubies/$build/bin/ruby" "${flags[@]}" "benchmarks/$bench/benchmark.rb" > "$out/$name.log" 2>&1) &
  pid=$!; wait $pid; rc=$?
  [ -f /tmp/perfetto-$pid.fxt ] && mv /tmp/perfetto-$pid.fxt "$out/$name.fxt"
  rm -rf "$copy"
  echo "$(date +%T) $job exit $rc $(( $(date +%s) - s ))s"
done
