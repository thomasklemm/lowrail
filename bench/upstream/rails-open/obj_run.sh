#!/bin/bash
# obj_run.sh: objects per call for every case x variant x mode -> obj.tsv
. /tmp/w/open/jobs.sh; out=/tmp/w/open/obj.tsv; : > $out
while IFS='|' read c cands modes; do for m in $modes; do modeenv $m
  for v in main aa $cands; do d=open-main; [ $v = main ] || [ $v = aa ] || d=$v
    o=$(cd $W/$d && PATH=$P:$PATH ruby $F /tmp/w/open/cpu_open.rb $c 2000 obj 2>/dev/null | tail -1)
    echo -e "$c\t$m\t$v\t$o" >> $out; done; done; done <<< "$JOBS"
echo OBJDONE >> $out
