#!/bin/bash
# rails/rails#59141 on ruby-bench railsbench: Rails main 50c54eed06 (~/w/rb-main) vs its parent c48c154e3f (~/w/rb-parent),
# master b7e8fad022. Counters first (ZJIT per-ISEQ on ~/w/rs, YJIT stats on ~/w/rm), then Callgrind run a per mode with
# the pinned Valgrind and the same fixed heap/warmup as cg_queue.sh. Strictly sequential; run after round2_queue.sh.
root=/home/user/workspace/repo
export PATH=$HOME/w/vg319brk/bin:$PATH
log() { echo "$(date +%T) $*" >> ~/w/logs/r59cg.log; }
gems=$(echo $HOME/w/rm/lib/ruby/gems/*)
for v in main parent; do
  export RUBY_BENCH_DIR=$HOME/w/rb-$v
  out=$HOME/w/stats59/$v; mkdir -p $out
  [ -f $out/zjit-railsbench.json ] || { RUBY_PREFIX=$HOME/w/rs GEM_HOME=$gems GEM_PATH=$gems $root/bench/upstream/zjit_yjit_gap_run.sh stats railsbench zjit-railsbench $out \
    --zjit --zjit-stats-iseq --zjit-exec-mem-size=512 --zjit-mem-size=1024; log "stats zjit $v $?"; }
  [ -f $out/yjit-railsbench.json ] || { RUBY_PREFIX=$HOME/w/rm $root/bench/upstream/zjit_yjit_gap_run.sh stats railsbench yjit-railsbench $out --yjit --yjit-stats=quiet; log "stats yjit $v $?"; }
done
export RUBY_PREFIX=$HOME/w/rm CGEXT=$HOME/w/cgext RUBY_GC_HEAP_INIT_BYTES=33554432 WARMUP_ITRS=40
for job in main:zjit parent:zjit main:yjit parent:yjit; do
  IFS=: read v mode <<< "$job"
  export RUBY_BENCH_DIR=$HOME/w/rb-$v
  case $mode in
    zjit) flags=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024 --zjit-perf=iseq) ;;
    yjit) flags=(--yjit --yjit-perf=iseq) ;;
  esac
  d=$HOME/w/cg59/$v-$mode; mkdir -p $d
  [ -f $d/railsbench-a.json ] && continue
  s=$(date +%s)
  $root/bench/upstream/zjit_yjit_gap_run.sh callgrind railsbench railsbench-a $d "${flags[@]}"
  log "cg59 $job rc=$? $(( $(date +%s) - s ))s brk=$(grep -l 'brk segment overflow' $d/*.log)"
done
log "r59141 done"
