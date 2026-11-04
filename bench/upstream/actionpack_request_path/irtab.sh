#!/bin/bash
# irtab.sh OUT "cases" "wts" "modes" REPS -> OUT/<case>-<wt><rep>-<mode>.txt (Ir per call)
out=$1; cases=$2; wts=$3; modes=$4; reps=${5:-3}; mkdir -p $out; jobs=$out/jobs.txt; : > $jobs
for c in $cases; do for w in $wts; do for m in $modes; do for r in $(seq 1 $reps); do echo "$c $w $m $r" >> $jobs; done; done; done; done
one() { c=$1; w=$2; m=$3; r=$4; ~/w/bench/irm.sh $w $c $m > $out/$c-$w$r-$m.txt 2>&1; }
export -f one; export out
xargs -P ${PAR:-3} -L 1 bash -c 'one "$@"' _ < $jobs
echo IRDONE
