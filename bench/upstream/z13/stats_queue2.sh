#!/bin/bash
# stats_queue.sh OUT JOB...  JOB = mode:bench, mode zjit (stats-iseq + ii build ~/w/rs), yjit (~/w/rm, --yjit-stats=quiet),
# yjitii (~/w/rs, --yjit, interpreted instructions per ISEQ only). Same warmup as the Callgrind cohort.
root=/home/user/workspace/repo; out=$1; shift
export RUBY_BENCH_DIR=${RUBY_BENCH_DIR:-$HOME/w/rb-noreap} WARMUP_ITRS=${WARMUP_ITRS:-150} MIN_BENCH_ITRS=10 RUBY_GC_HEAP_INIT_BYTES=33554432
for job in "$@"; do
  IFS=: read mode b <<< "$job"
  [ -f $out/$mode-$b.json ] && { echo "skip $job"; continue; }
  s=$(date +%s)
  case $mode in
    zjit) RUBY_PREFIX=$HOME/w/rs GAP_II=1 $root/bench/upstream/zjit_yjit_gap_run.sh stats $b $mode-$b $out --zjit --zjit-stats-iseq --zjit-exec-mem-size=512 --zjit-mem-size=1024 ;;
    yjit) RUBY_PREFIX=$HOME/w/rm $root/bench/upstream/zjit_yjit_gap_run.sh stats $b $mode-$b $out --yjit --yjit-stats=quiet ;;
    yjitii) RUBY_PREFIX=$HOME/w/rs GAP_II=1 $root/bench/upstream/zjit_yjit_gap_run.sh stats $b $mode-$b $out --yjit ;;
  esac
  echo "$(date +%T) $job exit $? $(( $(date +%s) - s ))s"
done
