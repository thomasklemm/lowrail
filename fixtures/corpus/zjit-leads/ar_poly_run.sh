#!/bin/bash
# ar_poly_run.sh OUT K P... : ar_poly.rb under the interpreter, YJIT and ZJIT, two Callgrind runs each (A/A) per P.
# Ir per op as in ar_run.sh; same environment.
set -uo pipefail
out=$1 k=$2; shift 2
here=$(cd "$(dirname "$0")" && pwd)
ruby=$RUBY_PREFIX/bin/ruby
export CG_EXT_DIR RUBY_GC_HEAP_INIT_BYTES=33554432 N=${N:-2000}
mkdir -p "$out"
for mode in ${MODES:-interp yjit zjit}; do
  flags=(); [ $mode = yjit ] && flags=(--yjit); [ $mode = zjit ] && flags=(--zjit)
  for run in a b; do
    for p in "$@"; do
      f=$out/poly-$k-$p.$mode.$run
      MODE=callgrind "$VG_PREFIX/bin/valgrind" --tool=callgrind --instr-atstart=no --smc-check=all-non-file \
        --callgrind-out-file="$f.cg" "$ruby" "${flags[@]}" "$here/ar_poly.rb" "$k" "$p" > "$f.json" 2> "$f.log"
      grep -q "brk segment overflow" "$f.log" && echo "BRK $f"
      ir0=$(awk '/^totals:/ {print $2}' "$f.cg.1"); irn=$(awk '/^totals:/ {print $2}' "$f.cg.2")
      echo "poly K=$k P=$p $mode $run Ir/op=$(echo "scale=1; ($irn - $ir0) / $N" | bc) $("$ruby" -rjson -e 'j=JSON.parse(STDIN.read); print "gate=#{j["gate"]} gc=#{j["gc"]}"' < "$f.json")"
    done
  done
done
