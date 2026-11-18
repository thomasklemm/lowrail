#!/usr/bin/env bash
# Census 10 runs, sequential labels. Fixed heap for every run.
set -u
cd /home/user/workspace/repo
. .amp/in/orb-backup/heap.sh
APPS=blog,writebook,codetriage,pingcrm,redprints-cfp,react-starter-kit,casa,hackatime
MAIN=rails/rails@4500a94c34d7052b84f81f6d7fd44f5bb8af3fff
S81=rails/rails@aab611acd84b4754e2403a9ab005532ccb0ed374
C9=rails/rails@50c54eed065b8bfb1b0bbb5fa770c859baa98f9b
step() { echo "== $* $(date -u +%T)"; "$@"; echo "exit $? $(date -u +%T)"; }
for phase in ${PHASES:-alloc cpu}; do
case $phase in
alloc)
  step mise exec ruby@4.0.9 -- script/census run --label a10m --aa --rails $MAIN --apps $APPS --modes interp,yjit --jobs ${AJOBS:-2}
  step mise exec ruby@4.0.9 -- script/census run --label a10s --aa --rails $S81 --apps $APPS --modes interp,yjit --jobs ${AJOBS:-2}
  step mise exec ruby@4.0.9 -- script/census run --label a10c9 --rails $C9 --apps $APPS --modes interp,yjit --jobs ${AJOBS:-2} ;;
cpu)
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c10m --aa --rails $MAIN --apps $APPS --modes interp --jobs ${JOBS:-2}
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c10s --rails $S81 --apps $APPS --modes interp --jobs ${JOBS:-2}
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c10c9 --rails $C9 --apps $APPS --modes interp --jobs ${JOBS:-2} ;;
esac
done
echo ALLDONE
