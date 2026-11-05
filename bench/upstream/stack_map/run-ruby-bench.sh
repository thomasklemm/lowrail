#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
base="$root/.lowrail/private/stack-map"
bench=$1 mode=$2 counter=$3 label=$4
export RUBY_BENCH_DIR=${RUBY_BENCH_DIR:-$base/ruby-bench}
export RAILS_PATH=${RAILS_PATH:-$base/rails}
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH"
export BUNDLE_GEMFILE="$RUBY_BENCH_DIR/benchmarks/$bench/Gemfile"
export STACK_MAP_APP=$bench STACK_MAP_COUNTER=$counter CENSUS_MODE=$mode
export STACK_MAP_OUT="$base/$bench-$mode-$counter-$label.json"
test ! -e "$STACK_MAP_OUT"
export CENSUS_WARMUP=${CENSUS_WARMUP:-5}
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000
export RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
export DATABASE_URL="sqlite3:$base/$bench-$mode-$counter-$label.sqlite3"
flags=(--disable-yjit)
if [[ $mode == yjit ]]; then flags=(--yjit --yjit-perf); fi
command=(ruby "${flags[@]}" -rbundler/setup -r"$root/bench/upstream/stack_map/ruby_bench.rb"
  "$RUBY_BENCH_DIR/benchmarks/$bench/benchmark.rb")
if [[ $counter == callgrind ]]; then
  export CENSUS_REQUESTS=${CENSUS_REQUESTS:-1} CENSUS_CPU_INTERVAL=65536
  export CENSUS_CPU_STACKS="$STACK_MAP_OUT.stacks"
  export CENSUS_CPU_EXT=${CENSUS_CPU_EXT:-$base/sampler-156a2dffe0d5/census_cpu_sampler.so}
  command=("$base/valgrind/bin/valgrind" --tool=callgrind --instr-atstart=no --smc-check=all-non-file
    --callgrind-out-file=/dev/null "${command[@]}")
else
  export CENSUS_REQUESTS=${CENSUS_REQUESTS:-20}
fi
"${command[@]}" > "$STACK_MAP_OUT.log" 2>&1
