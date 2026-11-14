#!/bin/bash
# cg_queue.sh OUT_ROOT JOB...   JOB = ruby:mode:bench:name  (ruby m|v409; mode interp|yjit|zjit; name a|b|c)
# Sequential ruby-bench Callgrind runs via bench/upstream/zjit_yjit_gap_run.sh with a fixed heap (32 MiB per pool).
root=/home/user/workspace/repo; out=$1; shift
for job in "$@"; do
  IFS=: read rb mode bench name <<< "$job"
  if [ $rb = m ]; then export RUBY_PREFIX=$HOME/w/rm CGEXT=$HOME/w/cgext RUBY_GC_HEAP_INIT_BYTES=33554432; unset RUBY_GC_HEAP_0_INIT_SLOTS RUBY_GC_HEAP_1_INIT_SLOTS RUBY_GC_HEAP_2_INIT_SLOTS RUBY_GC_HEAP_3_INIT_SLOTS RUBY_GC_HEAP_4_INIT_SLOTS
  else export RUBY_PREFIX=$HOME/w/r409 CGEXT=$HOME/w/cgext409 RUBY_GC_HEAP_0_INIT_SLOTS=838860 RUBY_GC_HEAP_1_INIT_SLOTS=419430 RUBY_GC_HEAP_2_INIT_SLOTS=209715 RUBY_GC_HEAP_3_INIT_SLOTS=104857 RUBY_GC_HEAP_4_INIT_SLOTS=52428; unset RUBY_GC_HEAP_INIT_BYTES; fi
  # Copy of ruby-bench with reaping_frequency: 0 (the pool reaper's 60 s timer compiles code mid-window) and 40 JIT
  # warmup iterations (once-per-iteration methods reach the call threshold at iteration ~29).
  export RUBY_BENCH_DIR=$HOME/w/rb-noreap WARMUP_ITRS=40
  case $mode:$name in
    interp:*) flags=(); export WARMUP_ITRS=5 ;;
    yjit:a) flags=(--yjit --yjit-perf=iseq) ;; yjit:b) flags=(--yjit --yjit-perf=codegen) ;; yjit:*) flags=(--yjit) ;;
    zjit:a) flags=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024 --zjit-perf=iseq) ;;
    zjit:b) flags=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024 --zjit-perf=hir) ;;
    zjit:*) flags=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024) ;;
  esac
  d=$out/$rb-$mode; mkdir -p $d
  [ -f $d/$bench-$name.json ] && { echo "skip $job"; continue; }
  s=$(date +%s)
  mkdir -p $HOME/w/rbc; $root/bench/upstream/zjit_yjit_gap_run.sh callgrind $bench $bench-$name $d "${flags[@]}"; rc=$?
  echo "$(date +%T) $job exit $rc $(( $(date +%s) - s ))s"
done
