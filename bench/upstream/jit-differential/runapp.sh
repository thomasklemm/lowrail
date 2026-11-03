#!/bin/bash
# runapp.sh BUILD MODE APP TAG
build=$1 mode=$2 app=$3 tag=${4:-0}
source ~/jitdiff/env.sh $build
case $mode in
  interp) jit="";;
  z1) jit="--zjit --zjit-call-threshold=1";;
  z1ni) jit="--zjit --zjit-call-threshold=1 --zjit-inline-threshold=0";;
  zinl) jit="--zjit --zjit-call-threshold=1 --zjit-inline-threshold=500";;
  y1) jit="--yjit --yjit-call-threshold=1";;
  zmem) jit="--zjit --zjit-call-threshold=1 --zjit-mem-size=4";;
  ymem) jit="--yjit --yjit-call-threshold=1 --yjit-exec-mem-size=4 --yjit-code-gc";;
  zinv) jit="--zjit --zjit-call-threshold=2 --zjit-num-profiles=1 --zjit-num-exits-until-invalidate=1";;
  zc) jit="--zjit --zjit-call-threshold=3 --zjit-num-profiles=2"; export JITDIFF_COMPACT=1;;
  yc) jit="--yjit --yjit-call-threshold=1"; export JITDIFF_COMPACT=1;;
  ic) jit=""; export JITDIFF_COMPACT=1;;
  z2) jit="--zjit --zjit-call-threshold=2 --zjit-num-profiles=1";;
  z2i) jit="--zjit --zjit-call-threshold=3 --zjit-num-profiles=2 --zjit-inline-threshold=200";;
  z30) jit="--zjit";;
  z3) jit="--zjit --zjit-call-threshold=3 --zjit-num-profiles=2";;
  y3) jit="--yjit --yjit-call-threshold=3";;
  y30) jit="--yjit";;
  y2) jit="--yjit --yjit-call-threshold=2";;
  zdh) jit="--zjit --zjit-call-threshold=1 --zjit-disable-hir-opt";;
  zmv) jit="--zjit --zjit-call-threshold=2 --zjit-num-profiles=1 --zjit-max-versions=1";;
  zinb) jit="--zjit --zjit-call-threshold=1 --zjit-inline-threshold=500 --zjit-inline-budget=2000";;
  zcm) jit="--zjit --zjit-call-threshold=1 --zjit-mem-size=4"; export JITDIFF_COMPACT=1;;
esac
work=$HOME/jitdiff/apprun/$build-$app-$mode-$tag${JITDIFF_REPEAT:+-rep}
rm -rf $work; mkdir -p $(dirname $work); cp -a $HOME/jitdiff/apps/$app $work
[ -n "$JITDIFF_REPEAT" ] && mode_sfx=-rep$JITDIFF_REPEAT
out=$HOME/jitdiff/out/$build$mode_sfx/app-$app; mkdir -p $out
export BUNDLE_GEMFILE=$work/Gemfile BUNDLE_PATH=$HOME/jitdiff/appgems-$build
export JITDIFF_OUT=$out/$mode-$tag.json PARALLEL_WORKERS=1 RAILS_ENV=test SEED=${SEED:-41231}
export RUBYOPT="$jit -r$HOME/jitdiff/outcomes.rb"
rm -f $JITDIFF_OUT
cd $work
start=$(date +%s)
timeout ${TMO:-7200} bin/rails test --seed $SEED > $out/$mode-$tag.log 2>&1
code=$?
echo "$build $mode app-$app $tag exit=$code secs=$(( $(date +%s)-start ))" | tee -a $HOME/jitdiff/out/runs.txt
