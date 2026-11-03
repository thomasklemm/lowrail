#!/bin/bash
# run.sh BUILD MODE COMPONENT [TAG] [-- files...]
# MODE: interp | z1 | z1ni | zinl | y1
build=$1 mode=$2 comp=$3 tag=${4:-0}
label=$comp; case $comp in actionview-*) export JITDIFF_GROUP=${comp#actionview-}; comp=actionview;; esac; shift 4 2>/dev/null; [ "$1" = "--" ] && shift
source ~/jitdiff/env.sh $build
[ "$comp" = actioncable ] && export BUNDLE_GEMFILE=$HOME/jitdiff/bundle-cable/Gemfile
[ -n "$RAILS_DIR" ] && export BUNDLE_GEMFILE=$HOME/jitdiff/bundle-main/Gemfile
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
  z30) jit="--zjit";;
  z3) jit="--zjit --zjit-call-threshold=3 --zjit-num-profiles=2";;
  y3) jit="--yjit --yjit-call-threshold=3";;
  y30) jit="--yjit";;
esac
[ -n "$JITDIFF_REPEAT" ] && mode_sfx=-rep$JITDIFF_REPEAT
[ -n "$RAILS_DIR" ] && mode_sfx="$mode_sfx-main"
out=${OUTROOT:-$HOME/jitdiff/out}/$build$mode_sfx/$label; mkdir -p $out
export JITDIFF_OUT=$out/$mode-$tag.json PARALLEL_WORKERS=1 MT_CPU=1 SEED=${SEED:-41231} AJ_ADAPTER=inline ARCONN=sqlite3_mem
rm -f $JITDIFF_OUT
cd ${RAILS_DIR:-$HOME/workspace/repo/.corpus/rails}/$comp
start=$(date +%s)
flock /tmp/jitdiff-lock-$comp$mode_sfx timeout ${TMO:-7200} ruby $jit -rbundler/setup -r$HOME/jitdiff/outcomes.rb $HOME/jitdiff/run_component.rb "$@" --seed $SEED $EXTRA_ARGS > $out/$mode-$tag.log 2>&1
code=$?
echo "$build $mode $label $tag exit=$code secs=$(( $(date +%s)-start ))" | tee -a $HOME/jitdiff/out/runs.txt
