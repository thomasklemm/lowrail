#!/usr/bin/env bash
# Census 11 runs, sequential labels. Fixed heap for every run.
set -u
cd /home/user/workspace/repo
export PATH=$HOME/.local/bin:$PATH
. .amp/in/orb-backup/heap.sh
APPS=blog,writebook,codetriage,pingcrm,redprints-cfp,react-starter-kit,casa,hackatime
MAIN=rails/rails@cf0325a832a1594f01d866da1e4ad23d962d886b
S81=rails/rails@1afb398af94c3f76567d427a279637dbfaac8b3f
C10=rails/rails@4500a94c34d7052b84f81f6d7fd44f5bb8af3fff
step() { echo "== $* $(date -u +%T)"; "$@"; echo "exit $? $(date -u +%T)"; }
for phase in ${PHASES:-alloc cpu}; do
case $phase in
alloc)
  step mise exec ruby@4.0.9 -- script/census run --label a11m --aa --rails $MAIN --apps $APPS --modes interp,yjit --jobs ${AJOBS:-4}
  step mise exec ruby@4.0.9 -- script/census run --label a11s --aa --rails $S81 --apps $APPS --modes interp,yjit --jobs ${AJOBS:-4}
  step mise exec ruby@4.0.9 -- script/census run --label a11c10 --rails $C10 --apps $APPS --modes interp,yjit --jobs ${AJOBS:-4} ;;
cpu)
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c11m --aa --rails $MAIN --apps $APPS --modes interp --jobs ${JOBS:-4}
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c11s --rails $S81 --apps $APPS --modes interp --jobs ${JOBS:-4}
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c11c10 --rails $C10 --apps $APPS --modes interp --jobs ${JOBS:-4} ;;
esac
done
echo ALLDONE
sleep infinity
