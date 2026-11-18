#!/usr/bin/env bash
# One ruby-bench run for docs/upstream/zjit-stats-2026-11-18.md.
#   run.sh BENCH NAME OUT_DIR [RUBY_FLAGS...]
# RUBY_PREFIX: the build (default ~/rb/master). RUBY_BENCH_DIR: a ruby-bench checkout, copied per run
# because the apps write caches and databases. Extra flags (e.g. --zjit-trace-exits-sample-rate=N) are
# appended to the stats flags; a trace lands in /tmp/perfetto-PID.fxt.
set -euo pipefail
bench=$1 name=$2 out=$3; shift 3
prefix=${RUBY_PREFIX:-$HOME/rb/master}
src=${RUBY_BENCH_DIR:-$HOME/w/rb}
mkdir -p "$out"
out=$(cd "$out" && pwd)
copy="$HOME/w/rbc/$bench-$name"
rm -rf "$copy"; mkdir -p "$HOME/w/rbc"
cp -a "$src" "$copy"
cp "$(dirname "$0")/harness.rb" "$copy/harness/zstats.rb"
cd "$copy"
unset RUBYOPT
export PATH="$prefix/bin:$PATH" HARNESS=zstats JIT_STATS_JSON="$out/$name.json"
ruby --zjit --zjit-stats-quiet --zjit-exec-mem-size=512 --zjit-mem-size=1024 "$@" \
  "benchmarks/$bench/benchmark.rb" > "$out/$name.log" 2>&1
rm -rf "$copy"
