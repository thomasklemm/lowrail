#!/bin/bash
# GCI1 on lobsters: 2 stats processes (exit counts per arm), then 3 timed and 3 A/A processes, two at a time on cores 1 and 5.
cd "$(dirname "$0")"; until grep -q MICRO-DONE /tmp/micro.log; do sleep 10; done
O=$PWD/micro.jsonl; C=$HOME/w/ruby-cur/bin/ruby; H=$PWD/lob.rb
one() { local cpu=$1 run=$2; shift 2; (cd ~/w/ruby-bench && env PATH=$HOME/w/ruby-cur/bin:$PATH OUT=$O RUN=$run "$@" \
  taskset -c $cpu $C --zjit $ST -r$H benchmarks/lobsters/benchmark.rb > /tmp/lob-$run-$cpu.log 2>&1) || echo "FAIL $run"; }
ST=--zjit-stats-quiet one 1 stats & ST=--zjit-stats-quiet one 5 stats & wait
for k in 1 2 3; do ST= one 1 timed & ST= one 5 aa AA=1 & wait; done
echo LOB-DONE
