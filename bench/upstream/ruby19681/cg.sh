#!/usr/bin/env bash
# RUBY19681 Callgrind run: Ir spent inside ZJIT compilation, i.e. under with_compile_time_stat, the
# function whose wall time compile_time_ns counts.
#   cg.sh NAME BENCH OUT_DIR    NAME = master|head (~/rb/NAME)
# Pinned Valgrind 3.19 with the brk reservation (script/bench-valgrind ~/w/vg319brk), fixed heap,
# ruby-bench default harness with WARMUP_ITRS=5 MIN_BENCH_ITRS=1 MIN_BENCH_TIME=0 (compilation is
# nearly all done in the first iterations).
set -euo pipefail
name=$1 bench=$2 out=$3
mkdir -p "$out"; out=$(cd "$out" && pwd)
cd "${RB:-$HOME/w/rb}"
unset RUBYOPT
export PATH="$HOME/rb/$name/bin:$PATH" RUBY_GC_HEAP_INIT_BYTES=33554432 \
  WARMUP_ITRS=${WARMUP_ITRS:-5} MIN_BENCH_ITRS=1 MIN_BENCH_TIME=0
"$HOME/w/vg319brk/bin/valgrind" --tool=callgrind --smc-check=all-non-file \
  --toggle-collect='*with_compile_time_stat*' \
  --callgrind-out-file="$out/$bench-$name.cg" \
  ruby --zjit -e '
    at_exit { s = RubyVM::ZJIT.stats; $stderr.puts "ZSTATS " + %i[compile_time_ns compile_lir_time_ns compiled_iseq_count failed_iseq_count code_region_bytes].map { "#{_1}=#{s[_1]}" }.join(" ") }
    load ARGV.shift' "benchmarks/$bench/benchmark.rb" > "$out/$bench-$name.log" 2>&1
grep -c 'brk segment overflow' "$out/$bench-$name.log" || true
