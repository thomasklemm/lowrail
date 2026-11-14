#!/usr/bin/env bash
# Census 9 runs, sequential labels. Fixed heap for every run.
set -u
cd /home/user/workspace/repo
. .amp/in/orb-backup/heap.sh
APPS=blog,writebook,codetriage,pingcrm,redprints-cfp,react-starter-kit,casa,hackatime
MAIN=rails/rails@50c54eed065b8bfb1b0bbb5fa770c859baa98f9b
S81=rails/rails@71e963ed1b0c8e5d1ff6e9124236cf7c4d4a24b9
C8=rails/rails@1105756f426ee42834af5c87b4549ef709d631e5
K1=/home/user/workspace/repo/.corpus/rails@5e34cc61f813a664592bde90ca618c1850407f2a
step() { echo "== $* $(date -u +%T)"; "$@"; echo "exit $? $(date -u +%T)"; }
case ${1:-alloc} in
alloc)
  step mise exec ruby@4.0.9 -- script/census run --label a9m --aa --apps $APPS --modes interp,yjit --jobs 2
  step mise exec ruby@4.0.9 -- script/census run --label a9s --aa --rails $S81 --apps $APPS --modes interp,yjit --jobs 2
  step mise exec ruby@4.0.9 -- script/census run --label a9c8 --rails $C8 --apps $APPS --modes interp,yjit --jobs 2 ;;
cpu)
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c9m --aa --apps $APPS --modes interp --jobs ${JOBS:-2}
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c9s --aa --rails $S81 --apps $APPS --modes interp --jobs ${JOBS:-2}
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c9k --rails $K1 --apps $APPS --modes interp --jobs ${JOBS:-2}
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c9c8 --rails $C8 --apps $APPS --modes interp --jobs ${JOBS:-2} ;;
cpuyjit)
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c9m --aa --apps $APPS --modes yjit --jobs ${JOBS:-2}
  step mise exec ruby@4.0.9 -- script/cpu-census run --label c9s --aa --rails $S81 --apps $APPS --modes yjit --jobs ${JOBS:-2} ;;
esac
