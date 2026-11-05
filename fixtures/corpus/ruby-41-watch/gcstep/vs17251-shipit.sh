#!/bin/bash
# rb.sh ROUND MODE... : ruby-bench shipit, one build at a time
round=$1; shift
cd /tmp/w/ruby-bench
for mode in "$@"; do
  flags=""; [ $mode = yjit ] && flags=--yjit
  for l in master pr pool both; do
    case $l in master) rb=gsm pm=bytes ;; pr) rb=gsp pm=bytes ;; pool) rb=gsm pm=slots ;; both) rb=gsp pm=slots ;; esac
    d=/tmp/w/rbsteps/$l-$round; mkdir -p $d
    PATH=/home/user/.rubies/ruby-$rb/bin:$PATH HARNESS=gcstep WARMUP_ITRS=15 BENCH_ITRS=40 RUBY_GC_POOL_MODE=$pm \
      GCSTEP_LOG=$d/shipit-$mode GCSTEP_OUT=$d/shipit-$mode.json \
      ruby $flags benchmarks/shipit/benchmark.rb > /tmp/w/logs/rb-$l-$round-shipit-$mode.log 2>&1
    echo "$(date +%T) rb $round $mode $l rc=$?"
  done
done
echo RB-DONE
