#!/bin/bash
# usage: cg.sh TOOL(cachegrind|callgrind) DIR SCENARIO N TAG
tool=$1; dir=$2; s=$3; n=$4; tag=$5
cd $dir
export BUNDLE_GEMFILE=$dir/Gemfile BUNDLE_PATH=/tmp/gr/vendor RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
case $s in int_*) unset GRAPHQL_FUTURE;; *) export GRAPHQL_FUTURE=1;; esac
R=$(mise exec ruby@4.0.9 -- which ruby)
mkdir -p /tmp/cg
if [ $tool = callgrind ]; then o="--tool=callgrind --callgrind-out-file=/tmp/cg/$tag.$s.$n.out"; else o="--tool=cachegrind --cache-sim=no --cachegrind-out-file=/tmp/cg/$tag.$s.$n.out"; fi
valgrind $o $R -rbundler/setup /tmp/gqscripts/ex.rb $s $n > /tmp/cg/$tag.$s.$n.log 2>&1
grep -h "summary\|Collected" /tmp/cg/$tag.$s.$n.log | tail -1
