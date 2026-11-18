#!/bin/bash
# rsuite.sh BUILD MODE SUITE TAG ; SUITE = btest | test-all | test-spec | test-bundled-gems
build=$1 mode=$2 suite=$3 tag=${4:-0}
case $build in rel) bdir=$HOME/zd/build-rel;; dbg) bdir=$HOME/zd/build-dbg;; esac
c=""
case $mode in
  interp) jit="";;
  ic) jit=""; c=1;;
  z1) jit="--zjit --zjit-call-threshold=1";;
  z1ni) jit="--zjit --zjit-call-threshold=1 --zjit-inline-threshold=0";;
  zinl) jit="--zjit --zjit-call-threshold=1 --zjit-inline-threshold=500";;
  zinb) jit="--zjit --zjit-call-threshold=1 --zjit-inline-threshold=500 --zjit-inline-budget=2000";;
  zmem) jit="--zjit --zjit-call-threshold=1 --zjit-mem-size=4";;
  zcm) jit="--zjit --zjit-call-threshold=1 --zjit-mem-size=4"; c=1;;
  zinv) jit="--zjit --zjit-call-threshold=2 --zjit-num-profiles=1 --zjit-num-exits-until-invalidate=1";;
  zc) jit="--zjit --zjit-call-threshold=3 --zjit-num-profiles=2"; c=1;;
  z2i) jit="--zjit --zjit-call-threshold=3 --zjit-num-profiles=2 --zjit-inline-threshold=200";;
  z2) jit="--zjit --zjit-call-threshold=2 --zjit-num-profiles=1";;
  z3) jit="--zjit --zjit-call-threshold=3 --zjit-num-profiles=2";;
  z30) jit="--zjit";;
  zdh) jit="--zjit --zjit-call-threshold=1 --zjit-disable-hir-opt";;
  zmv) jit="--zjit --zjit-call-threshold=2 --zjit-num-profiles=1 --zjit-max-versions=1";;
  *) echo "bad mode $mode"; exit 2;;
esac
[ -n "$c" ] && jit="$jit -r$HOME/jitdiff/compact.rb"
out=$HOME/jitdiff/out/$build/ruby-$suite; mkdir -p $out
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.7/bin:$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin
cd $bdir; exec 9>/tmp/jitdiff-make-$build.lock; flock 9
start=$(date +%s)
case $suite in
  btest) timeout ${TMO:-7200} make -s btest RUN_OPTS="$jit" OPTS="-q" > $out/$mode-$tag.log 2>&1;;
  test-all) timeout ${TMO:-14400} make -s test-all RUN_OPTS="$jit" TESTOPTS="-j2 -q --tty=no --no-retry ${TESTOPTS_EXTRA}" ${TESTS:+TESTS="$TESTS"} > $out/$mode-$tag.log 2>&1;;
  test-spec) tflags=""; for f in $jit; do tflags="$tflags -T $f"; done
    timeout ${TMO:-7200} make -s test-spec MSPECOPT="-j" SPECOPTS="$tflags ${SPECOPTS_EXTRA}" > $out/$mode-$tag.log 2>&1;;
  test-bundled-gems) timeout ${TMO:-7200} make -s test-bundled-gems RUN_OPTS="$jit" > $out/$mode-$tag.log 2>&1;;
esac
code=$?
echo "$build $mode ruby-$suite $tag exit=$code secs=$(( $(date +%s)-start ))" | tee -a $HOME/jitdiff/out/runs.txt
