#!/bin/bash
# #59141 counters on census5 lobsters and fizzy: ZJIT per-ISEQ (stats-iseq build ~/w/rs) and YJIT stats (~/w/rm),
# Rails main 50c54eed06 vs #59141's parent c48c154e3f.
cd /home/user/workspace/repo
P=c48c154e3f5285cb2fe4cf03b2e3a62cfd34ffc8
export CENSUS_WARMUP=200
for v in main parent; do
  rails=(); [ $v = parent ] && rails=(--rails $P)
  mise exec -- script/census run --label r2s-$v "${rails[@]}" --ruby ~/w/rs --modes zjit --apps lobsters,fizzy --corpus census5 \
    "--stats=--zjit-stats-iseq --zjit-exec-mem-size=512 --zjit-mem-size=1024"; echo "zjit $v $?"
  mise exec -- script/census run --label r2y-$v "${rails[@]}" --ruby ~/w/rm --modes yjit --apps lobsters,fizzy --corpus census5 --stats; echo "yjit $v $?"
done
