#!/usr/bin/env bash
# Interleaved main / ANALYZE wall time on Ruby 4.0.9, one process at a time, pinned to CPU 1:
# 5 warmup + 20 measured iterations (as in #565), ROUNDS rounds, interpreter and YJIT.
set -u
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH
out=$HOME/rb4/out/wall; mkdir -p "$out"
for round in $(seq 1 "${ROUNDS:-5}"); do
  for b in ${BENCHES:-railsbench activerecord sequel}; do
    for mode in interp yjit; do
      for tree in base-a anlz-a; do
        flags=""; [ $mode = yjit ] && flags=--yjit
        (cd $HOME/rb4/$tree && DATABASE_URL=sqlite3:$out/$tree-railsbench.sqlite3 \
          WARMUP_ITRS=5 MIN_BENCH_ITRS=20 MIN_BENCH_TIME=0 OUT_CSV_PATH=/tmp/rb4-ign.csv \
          setarch x86_64 -R taskset -c 1 ruby $flags benchmarks/$b/benchmark.rb 2>&1 \
          | grep "Average of last" | sed "s/^/$round $b $mode $tree /") >> "$out/results.txt"
      done
    done
  done
done
echo BENCH_DONE >> "$out/results.txt"
