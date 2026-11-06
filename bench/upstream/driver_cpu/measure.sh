#!/usr/bin/env bash
set -euo pipefail
root=$(realpath "$(dirname "$0")/../../..")
out=$(realpath -m "$1"); shift
mkdir "$out"
export PATH="${RUBY_BIN:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin}:$PATH"
export PDRV_RAILS=${PDRV_RAILS:-/tmp/pdrv/rails}
export CASES=${CASES:-$root/bench/upstream/driver_cpu/cases.rb}
export CG_EXT=${CG_EXT:-/tmp/pdrv/cg/lowrail_callgrind.so}
export FIXED_HEAP=1
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000
export RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
mode=${MODE:-interpreter}
flags=(--disable-yjit)
export WINDOW_WARMUP=${WINDOW_WARMUP:-50}
if [[ $mode == yjit ]]; then
  flags=(--yjit)
  export WINDOW_WARMUP=667
fi
names=${NAMES:-find_driver,find_adapter,find_model,select20_driver,select20_adapter,select20_model,select1000_driver,select1000_adapter,select1000_model,wide20_driver,wide20_adapter,wide20_model,wide1000_driver,wide1000_adapter,wide1000_model,pluck_driver,pluck_adapter,pluck_model}
for rep in $(seq "${REPS:-3}"); do
  for tree in "$@"; do
    label=$(basename "$tree")
    prefix="$out/$label-$rep"
    echo "$mode ${DRIVER:-sqlite3} ${PREPARED:-1} $label $rep"
    BUNDLE_GEMFILE="$tree/Gemfile" RAILS_PATH="$tree" \
      "${VALGRIND:-$HOME/vg-brk512/bin/valgrind}" --tool=callgrind --instr-atstart=no \
      --smc-check=all-non-file --callgrind-out-file="$prefix.cg" \
      ruby "${flags[@]}" -rbundler/setup "$root/bench/upstream/census_backlog/refresh_window.rb" \
      "$names" "${COUNT:-5}" > "$prefix.jsonl" 2> "$prefix.log"
    if rg -q 'brk segment overflow' "$prefix.log"; then
      echo "brk overflow: $prefix" >&2
      exit 1
    fi
  done
done
