#!/usr/bin/env bash
# Census 12 runs, one label at a time on one orb. Fixed heap for every run.
# Labels: main 088fc0cf61 (c12m/c12m2, a12m/a12m2), v8.1.4.1 (c12s, a12s/a12s2),
# census 11's main cf0325a832 (c12c11, a12c11). YJIT CPU mode only for c12m/c12m2 and c12s.
set -u
cd /home/user/workspace/repo
export PATH=$HOME/.local/bin:$PATH
. bench/upstream/census12/heap.sh
APPS=blog,writebook,codetriage,pingcrm,redprints-cfp,react-starter-kit,casa,hackatime
MAIN=rails/rails@088fc0cf61e4ba0c7987decafacc69adb3e22eec
S81=rails/rails@3f290b759c8e2ffe7c257951b1255740751355e4
C11=rails/rails@cf0325a832a1594f01d866da1e4ad23d962d886b
step() { echo "== $* $(date -u +%T)"; "$@"; echo "exit $? $(date -u +%T)"; }
for phase in ${PHASES:-cpu alloc cpuyjit}; do
case $phase in
cpu)
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c12m --aa --rails $MAIN --apps $APPS --modes interp --jobs ${JOBS:-4}
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c12s --rails $S81 --apps $APPS --modes interp --jobs ${JOBS:-4}
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c12c11 --rails $C11 --apps $APPS --modes interp --jobs ${JOBS:-4} ;;
alloc)
  step mise exec ruby@4.0.9 -- script/census run --label a12m --aa --rails $MAIN --apps $APPS --modes interp,yjit --jobs ${AJOBS:-4}
  step mise exec ruby@4.0.9 -- script/census run --label a12s --aa --rails $S81 --apps $APPS --modes interp,yjit --jobs ${AJOBS:-4}
  step mise exec ruby@4.0.9 -- script/census run --label a12c11 --rails $C11 --apps $APPS --modes interp,yjit --jobs ${AJOBS:-4} ;;
cpuyjit)
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c12m --aa --rails $MAIN --apps $APPS --modes yjit --jobs ${JOBS:-4}
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c12s --rails $S81 --apps $APPS --modes yjit --jobs ${JOBS:-4} ;;
esac
done
echo ALLDONE
sleep infinity
