#!/bin/bash
# cg_queue.sh OUT_ROOT CPUS JOB...   JOB = build:mode:bench:name  (build base|fix; mode interp|yjit|zjit; name a|b)
# Sequential ruby-bench Callgrind runs via bench/upstream/zjit_yjit_gap_run.sh, pinned Valgrind (512 MiB brk),
# fixed heap (RUBY_GC_HEAP_INIT_BYTES=32 MiB per heap), JIT-flat gate in harness/gap.rb.
root=/home/user/workspace/repo; out=$1; cpus=$2; shift 2
export PATH=$HOME/w/valgrind-brk512/bin:$PATH RUBY_GC_HEAP_INIT_BYTES=33554432 RUBY_BENCH_DIR=$HOME/w/rb-noreap
for job in "$@"; do
  IFS=: read b mode bench name <<< "$job"
  export RUBY_PREFIX=$HOME/w/inst/$b CGEXT=$HOME/w/cgext/$b WARMUP_ITRS=40
  case $mode in
    interp) flags=(); export WARMUP_ITRS=5 ;;
    yjit) flags=(--yjit) ;;
    zjit) flags=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024) ;;
  esac
  d=$out/$b-$mode; mkdir -p $d
  [ -f $d/$bench-$name.json ] && { echo "skip $job"; continue; }
  s=$(date +%s)
  mkdir -p $HOME/w/rbc
  taskset -c $cpus $root/bench/upstream/zjit_yjit_gap_run.sh callgrind $bench $bench-$name $d "${flags[@]}"; rc=$?
  grep -l "brk segment overflow" $d/$bench-$name.log && echo "BRK OVERFLOW $job"
  rm -rf $HOME/w/rbc/$bench-callgrind-$bench-$name-$(basename $d)
  echo "$(date +%T) $job exit $rc $(( $(date +%s) - s ))s"
done
