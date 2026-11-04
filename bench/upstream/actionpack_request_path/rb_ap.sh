#!/bin/bash
# rb_ap.sh OUT AP: ruby-bench Callgrind Ir per iteration, variants main1/main2 (A/A) and cand; Ruby 4.0.9
out=$1; ap=$2; mkdir -p $out
jobs=$out/jobs.txt; : > $jobs
for a in railsbench lobsters shipit; do for mode in interp yjit; do for v in main1 cand main2; do echo "$a $mode $v" >> $jobs; done; done; done
one() {
  app=$1; mode=$2; v=$3
  f=""; smc=""; w=1; [ $mode = yjit ] && { f="--yjit"; smc="--smc-check=all"; w=10; }
  c=0; [ $v = cand ] && c=1
  cd ~/w/ruby-bench && AP=$ap CAND=$c WARMUP_ITRS=$w IR_ITRS=1 HARNESS=lowrail_ap \
    PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle $smc \
    --callgrind-out-file=/dev/null ruby $f benchmarks/$app/benchmark.rb > $out/$app-$mode-$v.log 2>&1
  echo "$app $mode $v $(grep -o 'Collected : [0-9]*' $out/$app-$mode-$v.log)"
}
export -f one; export out ap
xargs -P ${PAR:-6} -L 1 bash -c 'one "$@"' _ < $jobs
echo RBDONE
