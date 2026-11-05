#!/bin/bash
# cc.sh BENCH VARIANT [TARGETS]  -> call counts for one iteration (native, TracePoint)
b=$1; v=$2
O=/home/user/workspace/repo/.lowrail/private/perf/cc; mkdir -p $O
cd /home/user/src/ruby-bench
export PATH=$(mise where ruby@4.0.9)/bin:$PATH
export BUNDLE_GEMFILE=$PWD/benchmarks/$b/Gemfile.$v HARNESS=callcount WARMUP_ITRS=2 CC_OUT=$O/$b-$v.json CG_RAILS=/home/user/src/wt/$v CC_TARGETS=$3
[ $b = railsbench ] && export DATABASE_URL=sqlite3:/tmp/cc-$b-$v.sqlite3
ruby benchmarks/$b/benchmark.rb > $O/$b-$v.log 2>&1
echo "EXIT $?" >> $O/$b-$v.log
