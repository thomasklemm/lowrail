#!/bin/bash
# cgrun.sh REV(master|head) REP(a|b) : Callgrind Ir of every scenario at two iteration counts
# Output: $OUT/REV-REP.SCEN.N.out and .log ; per-iteration Ir = (Ir(N2) - Ir(N1)) / (N2 - N1)
set -u
rev=$1; rep=$2
OUT=${OUT:-/home/user/w/cg}
case $rev in master) dir=/home/user/w/gm ;; head) dir=/home/user/w/gh ;; esac
mkdir -p $OUT
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
R=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
S=/home/user/workspace/repo/.amp/in/orb-backup/gq1
run() { # SCEN N kind(ex|ver)
  local s=$1 n=$2 k=$3 f=$OUT/$rev-$rep.$1.$2
  if [ $k = ex ]; then
    case $s in int_*) unset GRAPHQL_FUTURE ;; *) export GRAPHQL_FUTURE=1 ;; esac
    (cd $dir && BUNDLE_GEMFILE=$dir/Gemfile valgrind --tool=callgrind --callgrind-out-file=$f.out $R -rbundler/setup $S/ex.rb $s $n > $f.log 2>&1)
  else
    (cd /tmp && GQ_BENCH=$dir/benchmark valgrind --tool=callgrind --callgrind-out-file=$f.out $R -I$dir/lib $S/ver.rb $s $n > $f.log 2>&1)
  fi
  echo "$rev-$rep $s $n $(grep -h '^summary:\|^totals:' $f.out | head -1)"
}
for p in "val_abstract 10 40 ex" "val_big 5 20 ex" "val_merge 1 4 ex" "val_intro 10 40 ex" "next_intro 5 20 ex" "next_small 20 80 ex" "next_large 1 3 ex" "int_intro 2 8 ex" "exe_intro_big 2 6 ver"; do
  set -- $p
  run $1 $2 $4; run $1 $3 $4
done
