#!/bin/bash
# mb.sh OUTDIR ROUNDS: interleaved make benchmark runs pinned to CPU 14 (sibling 15 idle).
# aa = base build tree vs base installed; hb = head build tree vs base installed; vh = head build tree vs 4.0.9 installed.
out=$1; n=${2:-10}; mkdir -p $out
mb() { (cd ~/w/build-$1 && taskset -c 14 make benchmark ITEM=vm_backtrace_to_s COMPARE_RUBY=$2 OPTS="--repeat-count 10") > $3 2>&1; }
for i in $(seq 1 $n); do
  mb base ~/w/rubies/base/bin/ruby $out/aa-$i.txt
  mb head ~/w/rubies/base/bin/ruby $out/hb-$i.txt
  mb head ~/w/rubies/v409/bin/ruby $out/vh-$i.txt
  echo "$(date +%T) round $i"
done
