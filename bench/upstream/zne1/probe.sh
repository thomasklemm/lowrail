#!/usr/bin/env bash
# Differential probe for docs/upstream/zjit-not-equal.md: runs probe.rb on a master and a branch build of ruby,
# in the interpreter and under ZJIT at several call thresholds, and prints one line per run.
# Pass: within each configuration the md5 is the same for master and branch, exit 0 and empty stderr.
#   probe.sh MASTER_RUBY BRANCH_RUBY [OUT_DIR]
set -u
here=$(cd "$(dirname "$0")" && pwd)
master=$1; branch=$2; out=${3:-$(mktemp -d)}
mkdir -p "$out"
md5() { if command -v md5sum >/dev/null; then md5sum | cut -c1-12; else command md5 -q | cut -c1-12; fi; }
run() {
  n=$1; shift
  "$@" "$here/probe.rb" > "$out/probe-$n.txt" 2> "$out/probe-$n.err"
  echo "$n exit $? lines $(wc -l < "$out/probe-$n.txt" | tr -d ' ') md5 $(md5 < "$out/probe-$n.txt") stderr $(wc -c < "$out/probe-$n.err" | tr -d ' ')"
}
for b in master branch; do
  ruby=$master; [ $b = branch ] && ruby=$branch
  run $b-interp "$ruby"
  run $b-zjit "$ruby" --zjit
  run $b-zjit-t1 "$ruby" --zjit --zjit-call-threshold=1
  run $b-zjit-t2p1 "$ruby" --zjit --zjit-call-threshold=2 --zjit-num-profiles=1
  run $b-zjit-t6p5 "$ruby" --zjit --zjit-call-threshold=6 --zjit-num-profiles=5
  run $b-zjit-t12p10 "$ruby" --zjit --zjit-call-threshold=12 --zjit-num-profiles=10
done
echo "outputs in $out"
