#!/bin/bash
# rungs.sh ROUND MODE... : per app, all pool variants in parallel (equal contention).
round=$1; shift
export CENSUS_GC_OPS=1000
variants=${VARIANTS:-bytes slots 2xbytes minpages2 slotscap8}
base=/home/user/workspace/repo/.lowrail/private/ruby-41-watch
for mode in "$@"; do
  for a in ${APPS:-blog campfire writebook fizzy fizzy-mysql codetriage pingcrm redprints-cfp react-starter-kit lobsters}; do
    [ "$round" = s ] && [ "$a" = fizzy-mysql ] && continue  # bytes and slots both completed in round a
    for v in $variants; do
      out=$base/gs-$v-$round; mkdir -p $out /tmp/w/gsteps/$v-$round
      GCSTEP_LOG=/tmp/w/gsteps/$v-$round/$a-$mode RUBY_GC_POOL_MODE=$v \
        /tmp/w/c4.sh gcstep $a $mode profile $out/$a-$mode.json > /tmp/w/logs/gs-$v-$round-$a-$mode.log 2>&1 &
    done
    wait
    echo "$(date +%T) $round $mode $a"
  done
done
echo DONE-$round
