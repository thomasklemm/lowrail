#!/bin/bash
# cg_queue2.sh: cg_queue.sh with a lock directory per job, so that several lanes can share one job list. Optional WAIT_PID.
[ -n "$WAIT_PID" ] && while kill -0 $WAIT_PID 2>/dev/null; do sleep 20; done
# cg_queue.sh OUT_ROOT JOB...   JOB = mode:bench:name  (mode yjit|zjit; name a = perf map by ISEQ, b = by HIR/codegen, c = none)
# Z13 Callgrind cohort on master 3be2b028a7 (~/w/rm) via bench/upstream/zjit_yjit_gap_run.sh: pinned Valgrind 3.19 with the
# brk reservation, fixed heap (RUBY_GC_HEAP_INIT_BYTES=32 MiB), ruby-bench copy ~/w/rb-noreap (reaping_frequency: 0,
# verify_timeout: 1000000), 150 warmup iterations (YJIT's call threshold is 120 on these apps), then at least 8 and at most
# 30 warm windows of 3 iterations until 2 in a row are JIT-flat, then up to 4 measured attempts (a failed one is kept as
# rejected and the harness re-warms to flat).
root=/home/user/workspace/repo; out=$1; shift
export PATH=$HOME/w/vg319brk/bin:$PATH RUBY_PREFIX=$HOME/w/rm CGEXT=$HOME/w/cgext RUBY_GC_HEAP_INIT_BYTES=33554432
export RUBY_BENCH_DIR=${RUBY_BENCH_DIR:-$HOME/w/rb-noreap} WARMUP_ITRS=150 FLAT_MIN_WINDOWS=8 FLAT_MAX_WINDOWS=30 MEASURE_ATTEMPTS=4
for job in "$@"; do
  IFS=: read mode bench name <<< "$job"
  case $mode:$name in
    yjit:a) flags=(--yjit --yjit-perf=iseq) ;; yjit:b) flags=(--yjit --yjit-perf=codegen) ;; yjit:*) flags=(--yjit) ;;
    zjit:a) flags=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024 --zjit-perf=iseq) ;;
    zjit:b) flags=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024 --zjit-perf=hir) ;;
    zjit:*) flags=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024) ;;
  esac
  d=$out/$bench; mkdir -p $d
  [ -f $d/$mode-$name.json ] && { echo "skip $job"; continue; }
  mkdir $d/.lock-$mode-$name 2>/dev/null || { echo "locked $job"; continue; }
  s=$(date +%s)
  mkdir -p $HOME/w/rbc; $root/bench/upstream/zjit_yjit_gap_run.sh callgrind $bench $mode-$name $d "${flags[@]}"; rc=$?
  echo "$(date +%T) $job exit $rc $(( $(date +%s) - s ))s brk=$(grep -c 'brk segment overflow' $d/$mode-$name.log)"
done
