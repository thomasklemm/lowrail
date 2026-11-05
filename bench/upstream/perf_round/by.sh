#!/bin/bash
# by.sh BENCH VARIANT [RUBY=master|409] [TAG]  objects and slot bytes per iteration (fixed heap), JSON to .lowrail/private/perf/by/
b=$1; v=$2; r=${3:-master}; tag=${4:-a}
O=/home/user/workspace/repo/.lowrail/private/perf/by; mkdir -p $O
cd ~/src/ruby-bench
if [ $r = master ]; then export PATH=$HOME/ruby-master/bin:$PATH BUNDLE_GEMFILE=$PWD/benchmarks/$b/Gemfile.$v-r41
else export PATH=$(mise where ruby@4.0.9)/bin:$PATH BUNDLE_GEMFILE=$PWD/benchmarks/$b/Gemfile.$v; fi
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
export HARNESS=bytes WARMUP_ITRS=3 BENCH_ITRS=${ITRS:-10} BY_OUT=$O/$b-$v-$r-$tag.json
[ $b = railsbench ] && export DATABASE_URL=sqlite3:/tmp/by-$b-$v-$r-$tag.sqlite3
ruby ${JIT} benchmarks/$b/benchmark.rb > $O/$b-$v-$r-$tag.log 2>&1
echo "$b $v $r $tag EXIT $?"
