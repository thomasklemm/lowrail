#!/usr/bin/env bash
# stats.sh NAME OUT_DIR BENCH...  — ZJIT per-iteration stats (bench/upstream/zne1/stats_harness.rb as harness/zne1.rb)
# with the Ruby in ~/w/p-NAME, gems shared in ~/w/gems; one copy of ruby-bench per run (apps write databases).
set -uo pipefail
name=$1 out=$2; shift 2
mkdir -p "$out"
for b in "$@"; do
  copy=$HOME/w/rbc/$b-$name; rm -rf "$copy"; mkdir -p "$HOME/w/rbc"; cp -a "$HOME/w/ruby-bench" "$copy"
  ( cd "$copy" && unset RUBYOPT && export PATH="$HOME/w/p-$name/bin:$PATH" GEM_HOME=$HOME/w/gems GEM_PATH=$HOME/w/gems \
      HARNESS=zne1 ZNE1_JSON="$out/stats-$name-$b.json" RUBY_GC_HEAP_INIT_BYTES=33554432 &&
    ruby --zjit --zjit-stats-quiet "benchmarks/$b/benchmark.rb" > "$out/stats-$name-$b.log" 2>&1; echo "$name $b exit $?" )
  rm -rf "$copy"
done
