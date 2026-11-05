#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
base="$root/.lowrail/private/stack-map"
app=$1 mode=$2 counter=$3 label=$4
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH"
export BUNDLE_GEMFILE="$root/.corpus/censuspm-$app/Gemfile.census-1e235cee11b0"
export CENSUS_RAILS_SHA=1e235cee11b0a7aecb189d8837534807626287aa CENSUS_MODE=$mode
export STACK_MAP_APP=$app STACK_MAP_COUNTER=$counter STACK_MAP_OUT="$base/$app-$mode-$counter-$label.json"
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000
export RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
flags=(--disable-yjit)
if [[ $mode == yjit ]]; then flags=(--yjit --yjit-perf); fi
command=(ruby "${flags[@]}" -C "$root/.corpus/censuspm-$app" -rbundler/setup "$root/bench/upstream/stack_map/puma.rb")
if [[ $counter == callgrind ]]; then
  export CENSUS_CPU_EXT=${CENSUS_CPU_EXT:-$base/sampler-25278fbc9ff9/census_cpu_sampler.so}
  command=("$base/valgrind/bin/valgrind" --tool=callgrind --instr-atstart=no --smc-check=all-non-file
    --callgrind-out-file=/dev/null "${command[@]}")
fi
exec "${command[@]}"
