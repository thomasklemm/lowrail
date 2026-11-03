#!/bin/bash
# cg.sh RUBY LABEL -- Callgrind interpreter census, five apps at a time
rb=$1; label=$2
out=/home/user/workspace/repo/.lowrail/private/ruby-41-watch/$label
dumps=/tmp/w/cgdumps/$label
mkdir -p $out $dumps
export PATH=/tmp/w/valgrind-pinned/bin:$PATH CENSUS_CALLGRIND_EXT=/tmp/w/cg/$rb/lowrail_callgrind.so CENSUS_WARMUP=30
run() { CENSUS_VALGRIND=$dumps/$1.cg /tmp/w/c4.sh $rb $1 interpreter profile $out/$1-interpreter.json > /tmp/w/logs/cg-$label-$1.log 2>&1; }
for group in "blog campfire writebook fizzy fizzy-mysql" "codetriage pingcrm redprints-cfp react-starter-kit lobsters"; do
  for a in $group; do run $a & done
  wait
done
for a in blog campfire writebook fizzy fizzy-mysql codetriage pingcrm redprints-cfp react-starter-kit lobsters; do
  [ -f $out/$a-interpreter.json ] || echo "MISSING $label $a"
  grep -l 'brk segment overflow' $dumps/$a.cg.log && echo "BRK-REJECTED $label $a"
done
echo "$(date +%T) done $label"
