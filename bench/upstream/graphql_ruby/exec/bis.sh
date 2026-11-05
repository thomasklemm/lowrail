#!/bin/bash
# bis.sh LISTFILE : Ir of exe_intro_big and exe_large at each commit (one process each)
: > /tmp/gqscripts/bisjobs.txt
for c in $(cat $1); do
  [ -d /tmp/gqv/$c ] || (mkdir -p /tmp/gqv/$c && git -C /tmp/gr archive $c lib | tar x -C /tmp/gqv/$c)
  for x in exe_intro_big:1:3; do IFS=: read s a b <<<"$x"; for n in $a $b; do [ -f /tmp/cg/b$c-a.$s.$n.out ] || echo "/tmp/gqv/$c/lib b$c-a $s $n" >> /tmp/gqscripts/bisjobs.txt; done; done
done
xargs -P2 -L1 /tmp/gqscripts/cgv.sh < /tmp/gqscripts/bisjobs.txt
echo BISDONE
