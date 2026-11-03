#!/bin/bash
# ns_run.sh: interleaved wall time per call (ns), 7 rounds, main / A/A / variants, one process each, order reversed every other round.
. /tmp/w/open/jobs.sh; out=/tmp/w/open/ns.tsv; : > $out
for r in 1 2 3 4 5 6 7; do
  while IFS='|' read c cands modes; do for m in $modes; do modeenv $m
    order="main aa $cands"; [ $((r % 2)) = 0 ] && order="$(echo $order | tr ' ' '\n' | tac | tr '\n' ' ')"
    for v in $order; do d=open-main; [ $v = main ] || [ $v = aa ] || d=$v
      n=20000; case $c in preload_*) n=4000;; esac
      ns=$(cd $W/$d && PATH=$P:$PATH ruby $F /tmp/w/open/cpu_open.rb $c $n ns 2>/dev/null | tail -1)
      echo -e "$r\t$c\t$m\t$v\t$ns" >> $out; done; done; done <<< "$JOBS"
done
echo NSDONE >> /tmp/w/open/setup/ns-open.log
