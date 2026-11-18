#!/usr/bin/env bash
# raise_run.sh BENCH OUT_JSON: interpreter run of bench/upstream/zjit-stats/raise_harness.rb
set -euo pipefail
bench=$1 out=$2
copy=$HOME/w/rbc/$bench-raise
rm -rf "$copy"; cp -a $HOME/w/rb "$copy"
cp "$(dirname "$0")/raise_harness.rb" "$copy/harness/zraise.rb"
cd "$copy"; unset RUBYOPT
PATH=${RUBY_PREFIX:-$HOME/rb/master}/bin:$PATH HARNESS=zraise RAISE_JSON=$out ruby benchmarks/$bench/benchmark.rb > $out.log 2>&1
rm -rf "$copy"
