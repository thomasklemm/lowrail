#!/bin/bash
# Round 2 measurement queue after the stock-Valgrind brk rejection (2026-11-14 ~13:00). Strictly sequential.
# Pinned tool: ~/w/vg319brk (script/bench-valgrind). Every Callgrind log is checked for "brk segment overflow".
# Log: ~/w/logs/r2q.log. Steps can be skipped by deleting their output (each step skips when output exists).
cd /home/user/workspace/repo
export PATH=$HOME/w/vg319brk/bin:$PATH CPATH=$HOME/w/vg319brk/include
log() { echo "$(date +%T) $*" >> ~/w/logs/r2q.log; }
brk() { grep -l "brk segment overflow" "$@" 2>/dev/null; }
step=${1:-all}

# 1. Clean shipit GC round (no concurrent measurement).
[ -f ~/w/gcrb/slots-c/shipit-yjit.json ] || { bash .amp/in/orb-backup/gc_shipit.sh c interp yjit >> ~/w/logs/gc-shipit.log 2>&1; log "gc shipit c done"; }

# 2. Hash/kwsplat micro sweep, interpreter, A/A per Ruby.
for l in m-interp:rm:cgext v409-interp:r409:cgext409 m-interp-b:rm:cgext v409-interp-b:r409:cgext409; do
  IFS=: read lab pre ext <<< "$l"
  [ -f ~/w/kw2/$lab/cases.json ] && continue
  out=$HOME/w/kw2/$lab; mkdir -p $out
  valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=$out/cg.%p $HOME/w/$pre/bin/ruby -I $HOME/w/$ext \
    .amp/in/orb-backup/kw_sweep.rb $out/cases.json > $out/log 2>&1
  log "kw2 $lab rc=$? brk=$(brk $out/log)"
done

# 3. Whole-benchmark Callgrind cohort (zjit_yjit_gap_run.sh via cg_queue.sh), root ~/w/cg3. ruby-bench copy ~/w/rb-noreap has
#    reaping_frequency: 0 and verify_timeout: 1000000 (the cg2 YJIT window compiled the with_raw_connection verify! branch
#    after the pre-window GC.start pause; cg2 kept in ~/w/cg-rejected/verify-timeout).
bash .amp/in/orb-backup/cg_queue.sh $HOME/w/cg3 m:zjit:railsbench:a m:yjit:railsbench:a m:zjit:railsbench:c \
  m:zjit:lobsters:a m:yjit:lobsters:a m:zjit:shipit:a m:yjit:shipit:a \
  m:interp:railsbench:a v409:interp:railsbench:a v409:yjit:railsbench:a >> ~/w/logs/r2q.log 2>&1
log "cg3 done brk=$(brk $HOME/w/cg3/*/*.log | tr '\n' ' ')"

# 4. GC pool-budget census cells (YJIT, blog/fizzy/lobsters), A/A rounds a and b.
[ -f ~/w/logs/gc-census.done ] || { bash .amp/in/orb-backup/gc_census.sh a b >> ~/w/logs/gc-census.log 2>&1; touch ~/w/logs/gc-census.done; log "gc census done"; }
log "queue done"
