#!/bin/bash
# cg_queue.sh OUT_ROOT JOB...   JOB = build:mode:bench:name
#   build: a Ruby prefix under ~/rubies (m-master, h2); mode yjit|zjit; name a = perf map by ISEQ, other names none.
# Z1-2 Callgrind cohort (docs/upstream/zjit-gap-census-2.md), Z13's method (bench/upstream/z13/cg_queue2.sh) with one
# lane per build: pinned Valgrind 3.19 with the brk reservation, fixed heap (RUBY_GC_HEAP_INIT_BYTES=32 MiB), ruby-bench
# copy ~/w/rb-noreap (reaping_frequency: 0, verify_timeout: 1000000), 150 warmup iterations, then at least 8 and at most
# 30 warm windows of 3 iterations until 2 in a row are JIT-flat, then up to 4 measured attempts. Several lanes may share
# one job list (a lock directory per job).
root=/home/user/workspace/repo; out=$1; shift
export PATH=$HOME/w/vg319brk/bin:$PATH RUBY_GC_HEAP_INIT_BYTES=33554432
export RUBY_BENCH_DIR=${RUBY_BENCH_DIR:-$HOME/w/rb-noreap} WARMUP_ITRS=150 FLAT_MIN_WINDOWS=8 FLAT_MAX_WINDOWS=30 MEASURE_ATTEMPTS=4
for job in "$@"; do
  IFS=: read build mode bench name <<< "$job"
  case $mode:$name in
    yjit:a) flags=(--yjit --yjit-perf=iseq) ;; yjit:*) flags=(--yjit) ;;
    zjit:a) flags=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024 --zjit-perf=iseq) ;;
    zjit:*) flags=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024) ;;
  esac
  d=$out/$bench/$build; mkdir -p $d  # basename = build: zjit_yjit_gap_run.sh names its ruby-bench copy after it
  [ -f $d/$mode-$name.json ] && { echo "skip $job"; continue; }
  mkdir $d/.lock-$mode-$name 2>/dev/null || { echo "locked $job"; continue; }
  s=$(date +%s)
  mkdir -p $HOME/w/rbc
  RUBY_PREFIX=$HOME/rubies/$build CGEXT=$HOME/w/cgext-$build \
    $root/bench/upstream/zjit_yjit_gap_run.sh callgrind $bench $mode-$name $d "${flags[@]}"; rc=$?
  echo "$(date +%T) $job exit $rc $(( $(date +%s) - s ))s brk=$(grep -c 'brk segment overflow' $d/$mode-$name.log)"
done
