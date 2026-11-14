#!/bin/bash
# gc_census.sh ROUND... : GC pool-budget cells on census5 blog/fizzy/lobsters, YJIT, instrumented build ~/w/rgcs,
# master (RUBY_GC_POOL_MODE=bytes) and fix (slots) alternating per app. Labels gcbytes-R / gcslots-R.
cd /home/user/workspace/repo
for r in "$@"; do
  for a in blog fizzy lobsters; do
    for pm in bytes slots; do
      mkdir -p ~/w/gcsteps/$pm-$r
      CENSUS_GC_OPS=500 CENSUS_GC_MAJOR_BY=1 GCSTEP_LOG=$HOME/w/gcsteps/$pm-$r/$a-yjit RUBY_GC_POOL_MODE=$pm \
        mise exec -- script/census run --label gc$pm-$r --ruby ~/w/rgcs --modes yjit --apps $a --corpus census5 > ~/w/logs/gc-census-$pm-$r-$a.log 2>&1
      echo "$(date +%T) $r $a $pm rc=$?"
    done
  done
done
