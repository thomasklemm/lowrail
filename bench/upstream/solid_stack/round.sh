#!/usr/bin/env bash
# round.sh DB OUT: four labels in parallel (rel A/A, main A/A) on app copies 1-4.
DB=$1; OUT=$2
R=/home/user/workspace/repo/bench/upstream/solid_stack/run.sh
for spec in "1 rel a" "2 rel b" "3 main a" "4 main b"; do
  set -- $spec
  APP=/home/user/w/stackapp-$1 DBSUFFIX=_$1 DB=$DB OUT=$OUT OPS=${OPS:-40} LABEL=$DB-$2-$3 STACK=$2 $R > $OUT.$DB-$2-$3.err 2>&1 &
done
wait
echo done > $OUT.$DB.done
