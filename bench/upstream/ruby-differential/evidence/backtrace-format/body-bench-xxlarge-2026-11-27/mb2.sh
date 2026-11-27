#!/bin/bash
# mb2.sh OUTDIR ROUNDS: interleaved A/A and new-head runs on CPU 14 (sibling 15 idle).
# aa2 = base build tree vs base installed; hb2 = head 5fc1871eec build tree vs base installed.
out=$1; n=${2:-10}; mkdir -p $out
mb() { (cd ~/w/build-$1 && taskset -c 14 make benchmark ITEM=vm_backtrace_to_s COMPARE_RUBY=$2 OPTS="--repeat-count 10") > $3 2>&1; }
for i in $(seq 1 $n); do
  mb base ~/w/rubies/base/bin/ruby $out/aa2-$i.txt
  mb head2 ~/w/rubies/base/bin/ruby $out/hb2-$i.txt
  echo "$(date +%T) round $i"
done
