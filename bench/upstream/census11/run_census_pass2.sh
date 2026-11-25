#!/usr/bin/env bash
# Pass 2: codetriage without a schema cache file for every label (main's cache names
# PostgreSQL::IndexDefinition, which 8.1 cannot load), plus the alloc labels pass 1 lost to it.
set -u
cd /home/user/workspace/repo
export PATH=$HOME/.local/bin:$PATH
. .amp/in/orb-backup/heap.sh
until journalctl -u amp-svc-c11-census --no-pager 2>/dev/null | rg -q ALLDONE; do sleep 60; done
APPS=blog,writebook,codetriage,pingcrm,redprints-cfp,react-starter-kit,casa,hackatime
MAIN=rails/rails@cf0325a832a1594f01d866da1e4ad23d962d886b
S81=rails/rails@1afb398af94c3f76567d427a279637dbfaac8b3f
C10=rails/rails@4500a94c34d7052b84f81f6d7fd44f5bb8af3fff
step() { echo "== $* $(date -u +%T)"; "$@"; echo "exit $? $(date -u +%T)"; }
test -e .corpus/census-codetriage/db/schema_cache.yml && mv .corpus/census-codetriage/db/schema_cache.yml /tmp/codetriage-schema_cache-again.yml
B=.lowrail/private/c11-pass1-moved; mkdir -p $B
for l in a11m a11m2; do mkdir -p $B/$l; mv .lowrail/private/census/$l/codetriage-* $B/$l/ 2>/dev/null; done
for l in a11s a11s2 a11c10; do [ -d .lowrail/private/census/$l ] && mv .lowrail/private/census/$l $B/; done
for l in c11m c11m2; do mkdir -p $B/cpu-$l; mv .lowrail/private/cpu-census/$l/codetriage-* $B/cpu-$l/ 2>/dev/null; done
step mise exec ruby@4.0.9 -- script/census run --label a11m --aa --rails $MAIN --apps codetriage --modes interp,yjit --jobs 2
step mise exec ruby@4.0.9 -- script/census run --label a11s --aa --rails $S81 --apps $APPS --modes interp,yjit --jobs 4
step mise exec ruby@4.0.9 -- script/census run --label a11c10 --rails $C10 --apps $APPS --modes interp,yjit --jobs 4
step mise exec ruby@4.0.9 -- script/cpu-census run --label c11m --aa --rails $MAIN --apps codetriage --modes interp --jobs 2
echo PASS2DONE
sleep infinity
