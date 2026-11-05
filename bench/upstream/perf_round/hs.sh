#!/bin/bash
# hs.sh BENCH VARIANT   hash/wide-object scan of one iteration on Ruby master (Gemfile.VARIANT-r41)
b=$1; v=$2
cd ~/src/ruby-bench
export PATH=$HOME/ruby-master/bin:$PATH BUNDLE_GEMFILE=$PWD/benchmarks/$b/Gemfile.$v-r41 HARNESS=hashscan WARMUP_ITRS=2
export HS_OUT=/home/user/workspace/repo/.lowrail/private/perf/hs/$b-$v-r41.json CG_RAILS=/home/user/src/wt/$v
[ $b = railsbench ] && export DATABASE_URL=sqlite3:/tmp/hs-$b-$v.sqlite3
ruby benchmarks/$b/benchmark.rb > /tmp/hs-$b-$v.log 2>&1
echo "$b $v EXIT $?"
