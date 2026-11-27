#!/usr/bin/env bash
# JIT counters and ZJIT traces per operation for the census apps of bench/upstream/zjit_gap_bet/HANDOFF.md.
#   census_stats.sh OUT   (labels: m = master ZJIT, y = master YJIT, h = headline ZJIT, mt/ht = ZJIT with sampled traces)
# 200 warmup operations per workload, then 20 each (script/census run --stats); each run starts from the
# database snapshot. Traces move to OUT/LABEL/APP-zjit.fxt.
set -uo pipefail
out=$1
root=$(cd "$(dirname "$0")/../../.." && pwd); cd "$root"
master=$HOME/rubies/${MASTER:-master-0d399335b7} headline=$HOME/rubies/${HEADLINE:-h6-5c4239a16d}
Z="--zjit-exec-mem-size=512 --zjit-mem-size=1024"
T="--zjit-trace-exits --zjit-trace-exits-sample-rate=20 --zjit-trace-fallbacks-sample-rate=20"
export PATH=$("$HOME/.local/bin/mise" where ruby@4.0.9)/bin:$PATH CENSUS_WARMUP=200 RUBY_GC_HEAP_INIT_BYTES=33554432
run() { # LABEL PREFIX MODES FLAGS
  for app in campfire writebook; do
    [ -d "$out/$1" ] && ls "$out/$1/$app-"*.json > /dev/null 2>&1 && continue
    rm -rf ".corpus/censusz3-$app/storage" && cp -a ".corpus/censusz3-$app/storage.pristine" ".corpus/censusz3-$app/storage"
    script/census run --label "$1" --corpus censusz3 --ruby "$2/bin" --modes "$3" --apps "$app" --stats="$4" --out "$out" > "$out/$1-$app.log" 2>&1
    echo "$(date +%T) $1 $app exit $?"
    pid=$(ruby -rjson -e 'print JSON.parse(File.read(ARGV[0]))["pid"]' "$out/$1/$app-zjit.json" 2>/dev/null)
    if [ -n "$pid" ] && [ -f "/tmp/perfetto-$pid.fxt" ]; then mv "/tmp/perfetto-$pid.fxt" "$out/$1/$app-zjit.fxt"; fi
  done
}
mkdir -p "$out"
run m "$master" zjit "$Z"
run y "$master" yjit ""
run h "$headline" zjit "$Z"
run mt "$master" zjit "$Z $T"
run ht "$headline" zjit "$Z $T"
echo "census stats done $(date +%T)"
