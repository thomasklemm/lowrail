#!/bin/bash
# run4.sh RUBY LABEL MODE...  -- all apps in parallel per mode
rb=$1; label=$2; shift 2
out=/home/user/workspace/repo/.lowrail/private/ruby-41-watch/$label
mkdir -p $out
for mode in "$@"; do
  for a in ${APPS:-blog campfire writebook fizzy fizzy-mysql codetriage pingcrm redprints-cfp react-starter-kit lobsters}; do
    /tmp/w/c4.sh $rb $a $mode profile $out/$a-$mode.json > /tmp/w/logs/run4-$label-$a-$mode.log 2>&1 &
  done
  wait
  for a in ${APPS:-blog campfire writebook fizzy fizzy-mysql codetriage pingcrm redprints-cfp react-starter-kit lobsters}; do
    [ -f $out/$a-$mode.json ] || echo "MISSING $label $a $mode"
  done
  echo "$(date +%T) done $label $mode"
done
