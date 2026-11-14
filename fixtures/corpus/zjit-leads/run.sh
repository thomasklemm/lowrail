#!/bin/bash
# run.sh OUT CASE [K [P]] : micro.rb under the interpreter, YJIT and ZJIT, twice each (A/A) under the pinned
# Callgrind, plus one --zjit-stats and one --yjit-stats run. Ir per call = (Ir of the N-call dump − Ir of the
# empty dump) / N, from each dump's `totals:` line. Needs RUBY_PREFIX, VG_PREFIX (script/bench-valgrind) and
# CG_EXT_DIR (bench/callgrind.c built against RUBY_PREFIX).
set -uo pipefail
out=$1; shift
here=$(cd "$(dirname "$0")" && pwd)
ruby=$RUBY_PREFIX/bin/ruby
export CG_EXT_DIR RUBY_GC_HEAP_INIT_BYTES=33554432 N=${N:-100000}
mkdir -p "$out"
tag=$(IFS=-; echo "$*")
for mode in interp yjit zjit; do
  flags=(); [ $mode = yjit ] && flags=(--yjit); [ $mode = zjit ] && flags=(--zjit)
  for run in a b; do
    f=$out/$tag.$mode.$run
    MODE=callgrind "$VG_PREFIX/bin/valgrind" --tool=callgrind --instr-atstart=no --smc-check=all-non-file --callgrind-out-file="$f.cg" \
      "$ruby" --disable-gems "${flags[@]}" "$here/micro.rb" "$@" > "$f.json" 2> "$f.log"
    grep -q "brk segment overflow" "$f.log" && echo "BRK $f"
    ir0=$(awk '/^totals:/ {print $2}' "$f.cg.1"); irn=$(awk '/^totals:/ {print $2}' "$f.cg.2")
    echo "$tag $mode $run Ir/call=$(echo "scale=1; ($irn - $ir0) / $N" | bc) $(cat "$f.json" | "$ruby" -rjson -e 'j=JSON.parse(STDIN.read); print "gate=#{j["gate"]} gc=#{j["gc"]}"')"
  done
  if [ $mode != interp ]; then
    s=(--zjit-stats-quiet); [ $mode = yjit ] && s=(--yjit-stats=quiet)
    "$ruby" --disable-gems "${flags[@]}" "${s[@]}" "$here/micro.rb" "$@" > "$out/$tag.$mode.stats.json"
  fi
done
