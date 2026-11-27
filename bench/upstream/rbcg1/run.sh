#!/bin/bash
# usage: run.sh REF OUTDIR [ruby flags]  -- runs fib under callgrind with REF's harness, prints summary/totals per dump
set -e
REF=$1; OUT=$2; shift 2
R=/home/user/.local/share/mise/installs/ruby/4.0.9/bin; export PATH=$R:$PATH
WT=${RB_WT_ROOT:-/home/user/workspace/rb}/wt-$REF
[ -d $WT ] || git -C ${RB_REPO:-/home/user/workspace/rb/ruby-bench} worktree add -q --detach $WT $REF
rm -rf $OUT; mkdir -p $OUT
cd $WT
WARMUP_ITRS=${WARMUP_ITRS:-1} MIN_BENCH_ITRS=${MIN_BENCH_ITRS:-2} HARNESS=callgrind \
  VALGRIND_OPTS="--callgrind-out-file=$OUT/cg.out.%p" \
  valgrind --tool=callgrind --instr-atstart=no ruby "$@" benchmarks/${BENCH:-fib}.rb > $OUT/stdout 2> $OUT/stderr
for f in $(ls $OUT/cg.out.* | sort); do
  printf '%s summary=%s totals=%s\n' "$(basename $f | sed 's/[0-9]\{3,\}/PID/')" "$(sed -n 's/^summary: //p' $f)" "$(sed -n 's/^totals: //p' $f)"
done
