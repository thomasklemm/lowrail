#!/bin/bash
# ir_run.sh: Callgrind Ir per call (N=0 and N=5000) for every case x variant x mode -> ir/*.out
. /tmp/w/open/jobs.sh; out=/tmp/w/open/ir; mkdir -p $out
jobs=/tmp/w/open/ir-jobs.txt; : > $jobs
while IFS='|' read c cands modes; do for m in $modes; do for v in main aa $cands; do for n in 0 5000; do
  echo "$c $v $m $n" >> $jobs; done; done; done; done <<< "$JOBS"
one() {
  . /tmp/w/open/jobs.sh; c=$1 v=$2 m=$3 n=$4; modeenv $m
  d=open-main; [ $v = main ] || [ $v = aa ] || d=$v
  smc=""; [ -n "$F" ] && smc="--smc-check=all"
  cd $W/$d && PATH=$P:$PATH /tmp/vg/bin/valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle $smc \
    --callgrind-out-file=/dev/null ruby $F /tmp/w/open/cpu_open.rb $c $n ir > /tmp/w/open/ir/$c-$v-$m-$n.out 2>&1
}
export -f one
xargs -P 7 -L 1 bash -c 'one "$@"' _ < $jobs
echo IRDONE
