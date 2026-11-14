#!/bin/bash
# cg_job.sh LABEL BENCH NAME : ruby-bench Callgrind window via bench/upstream/zjit_yjit_gap_run.sh, pinned Valgrind,
# fixed heap, 40 warmup iterations, JIT-flat gate. LABEL base|branch (ZJIT) or base-yjit. Output ~/w/zl3/cg/LABEL.
label=$1 bench=$2 name=$3
build=${label%-yjit}
export PATH=$HOME/w/vg/bin:$PATH RUBY_PREFIX=/home/user/workspace/inst-$build CGEXT=$HOME/w/cgext-$build \
  RUBY_GC_HEAP_INIT_BYTES=33554432 RUBY_BENCH_DIR=$HOME/w/rb-noreap WARMUP_ITRS=40
flags=(--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024); [[ $label == *-yjit ]] && flags=(--yjit)
d=$HOME/w/zl3/cg/$label; mkdir -p $d $HOME/w/rbc
s=$(date +%s)
/home/user/workspace/repo/bench/upstream/zjit_yjit_gap_run.sh callgrind $bench $bench-$name $d "${flags[@]}"; rc=$?
grep -l "brk segment overflow" $d/$bench-$name.log && echo "BRK $label $bench $name"
for f in $d/$bench-$name.cg.*; do awk '/^totals:/ {print FILENAME, $2}' $f; done
rm -f $d/$bench-$name.cg.*
echo "$(date +%T) $label $bench $name exit $rc $(( $(date +%s) - s ))s"
