#!/bin/bash
# runrb-seq.sh ROUND MODE... : ruby-bench railsbench/lobsters/shipit, one pool variant at a time.
round=$1; shift
R=/home/user/.rubies/ruby-gcstep/bin
cd /tmp/w/ruby-bench
for mode in "$@"; do
  flags=""; [ $mode = yjit ] && flags=--yjit
  for b in railsbench lobsters shipit; do
    for v in ${VARIANTS:-bytes slots}; do
      d=/tmp/w/rbsteps/$v-$round; mkdir -p $d
      rm -rf benchmarks/lobsters/tmp/cache
      PATH=$R:$PATH HARNESS=gcstep WARMUP_ITRS=${WARMUP_ITRS:-15} BENCH_ITRS=${BENCH_ITRS:-40} RUBY_GC_POOL_MODE=$v \
        GCSTEP_LOG=$d/$b-$mode GCSTEP_OUT=$d/$b-$mode.json \
        ruby $flags benchmarks/$b/benchmark.rb > /tmp/w/logs/rb-$v-$round-$b-$mode.log 2>&1
      echo "$(date +%T) rb $round $mode $b $v rc=$?"
    done
  done
done
