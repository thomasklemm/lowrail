#!/bin/bash
# HEAPENV=RUBY_GC_HEAP_INIT_BYTES=33554432 micro.sh PREFIX TAG: Ir per String#dup call, slope between N=50,000 and N=250,000.
p=$1; tag=$2; d=/tmp/cg; mkdir -p $d
for n in 50000 250000; do
  env $HEAPENV valgrind --tool=callgrind --smc-check=all-non-file --callgrind-out-file=$d/$tag-$n.cg \
    $p/bin/ruby --disable-gems --zjit --zjit-call-threshold=2 $(dirname $0)/dup_micro.rb $n > $d/$tag-$n.log 2>&1
done
a=$(grep -m1 '^summary:' $d/$tag-50000.cg | awk '{print $2}'); b=$(grep -m1 '^summary:' $d/$tag-250000.cg | awk '{print $2}')
echo "$tag $(( (b - a) / 200000 )) Ir per call ($a, $b)"
