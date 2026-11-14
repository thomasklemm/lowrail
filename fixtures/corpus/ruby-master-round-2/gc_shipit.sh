#!/bin/bash
# gc_shipit.sh ROUND MODE... : ruby-bench shipit on the gcstep build (~/w/rgcs), master (bytes) and fix (slots) alternating
round=$1; shift
cd ~/w/ruby-bench
for mode in "$@"; do
  flags=""; [ $mode = yjit ] && flags=--yjit
  for pm in bytes slots; do
    d=~/w/gcrb/$pm-$round; mkdir -p $d
    env -u RUBYOPT PATH=$HOME/w/rgcs/bin:$PATH HARNESS=gcstep WARMUP_ITRS=15 BENCH_ITRS=40 RUBY_GC_POOL_MODE=$pm \
      GCSTEP_LOG=$d/shipit-$mode GCSTEP_OUT=$d/shipit-$mode.json ruby $flags benchmarks/shipit/benchmark.rb > $d/shipit-$mode.log 2>&1
    echo "$(date +%T) shipit $round $mode $pm rc=$?"
  done
done
