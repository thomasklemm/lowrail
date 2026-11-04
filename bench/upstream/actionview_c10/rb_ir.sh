#!/bin/bash
# tag_rb_ir.sh DIR MODE OUT: railsbench Callgrind Ir per iteration for base1 t1 t2 base2
dir=$1 mode=$2 out=$3; mkdir -p $out
f=""; smc=""; w=1; [ $mode = yjit ] && { f="--yjit"; smc="--smc-check=all"; w=10; }
for v in base1 t1 t2 base2; do
  cd $dir && TAG_VARIANT=${v%[12]} WARMUP_ITRS=$w IR_ITRS=1 HARNESS=lowrail_tagir \
    mise exec ruby@4.0.9 -- valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle $smc \
    --callgrind-out-file=/dev/null ruby $f benchmarks/railsbench/benchmark.rb > $out/railsbench-$mode-$v.log 2>&1
  echo "railsbench $mode $v $(grep -o 'Collected : [0-9]*' $out/railsbench-$mode-$v.log)"
done
