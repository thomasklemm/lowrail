#!/bin/bash
# Build miniruby variants of the sweep budgets on master b51db981 and run the bigslot repro on each.
cd /tmp/w/sweep
export PATH=$(mise where ruby@4.0.7)/bin:$PATH
build() { # name sweep_expr pool_expr
  git checkout -q gc/default/default.c
  sed -i "s|    int sweep_budget = GC_INCREMENTAL_SWEEP_BYTES / heap->slot_size;|    int sweep_budget = $2;|; s|    int pool_budget = GC_INCREMENTAL_SWEEP_POOL_BYTES / heap->slot_size;|    int pool_budget = $3;|" gc/default/default.c
  make -j6 miniruby > /tmp/w/sweep-build-$1.log 2>&1 && cp miniruby /tmp/w/sweep-$1
}
build v1x2   "GC_INCREMENTAL_SWEEP_BYTES * 2 / heap->slot_size" "GC_INCREMENTAL_SWEEP_POOL_BYTES * 2 / heap->slot_size"
build vslots "2048" "1024"
build vpool  "GC_INCREMENTAL_SWEEP_BYTES / heap->slot_size" "1024"
build vsweep "2048" "GC_INCREMENTAL_SWEEP_POOL_BYTES / heap->slot_size"
git checkout -q gc/default/default.c
for v in v0 v1x2 vslots vpool vsweep; do
  for ring in 200 300; do
    echo "$v ring $ring: $(RING=$ring BIG=70 N=40000 /tmp/w/sweep-$v /tmp/w/repro/bigslot.rb)"
  done
done
echo VARIANTS-DONE
