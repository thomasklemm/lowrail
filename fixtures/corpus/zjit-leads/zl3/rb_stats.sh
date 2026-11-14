#!/bin/bash
# rb_stats.sh LABEL BENCH NAME : ruby-bench stats run (WARMUP_ITRS=40, 10 measured) via bench/upstream/zjit_yjit_gap_run.sh
# on build LABEL (base|branch) with ZJIT stats; JSON in ~/w/zl3/stats/LABEL.
label=$1 bench=$2 name=$3
export RUBY_PREFIX=/home/user/workspace/inst-$label RUBY_BENCH_DIR=$HOME/w/rb-noreap WARMUP_ITRS=${WARMUP_ITRS:-40} RUBY_GC_HEAP_INIT_BYTES=33554432
mkdir -p $HOME/w/rbc
/home/user/workspace/repo/bench/upstream/zjit_yjit_gap_run.sh stats $bench $bench-$name $HOME/w/zl3/stats/$label \
  ${MODE_FLAGS:---zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024 --zjit-stats-quiet}
echo "$label $bench $name exit $?"
