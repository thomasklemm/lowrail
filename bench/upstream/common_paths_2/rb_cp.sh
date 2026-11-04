#!/bin/bash
# rb_cp.sh OUT CP: ruby-bench Callgrind Ir per iteration, variants main1/main2 (A/A) and cand
out=$1; cp=$2; mkdir -p $out
app_run() {
  app=$1
  for mode in interp yjit; do
    f=""; smc=""; w=1; [ $mode = yjit ] && { f="--yjit"; smc="--smc-check=all"; w=10; }
    for v in main1 cand main2; do
      c=0; [ $v = cand ] && c=1
      cd ~/work/ruby-bench && CP=$cp CAND=$c WARMUP_ITRS=$w IR_ITRS=1 HARNESS=lowrail_cp \
        mise exec ruby@4.0.9 -- valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle $smc \
        --callgrind-out-file=/dev/null ruby $f benchmarks/$app/benchmark.rb > $out/$app-$mode-$v.log 2>&1
      echo "$app $mode $v $(grep -o 'Collected : [0-9]*' $out/$app-$mode-$v.log)"
    done
  done
}
for a in railsbench shipit lobsters; do app_run $a & done; wait; echo RBDONE
