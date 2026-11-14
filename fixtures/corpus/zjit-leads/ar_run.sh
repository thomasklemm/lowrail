#!/bin/bash
# ar_run.sh OUT : ar_read.rb, VARIANT sym and literal, interpreter / YJIT / ZJIT, two Callgrind runs each (A/A),
# alternating variants. Ir per op = (Ir of the N-op dump − Ir of the empty dump) / N. Same environment as run.sh,
# plus BUNDLE_GEMFILE.
set -uo pipefail
out=$1
here=$(cd "$(dirname "$0")" && pwd)
ruby=$RUBY_PREFIX/bin/ruby
export CG_EXT_DIR RUBY_GC_HEAP_INIT_BYTES=33554432 N=${N:-2000}
mkdir -p "$out"
for mode in interp yjit zjit; do
  flags=(); [ $mode = yjit ] && flags=(--yjit); [ $mode = zjit ] && flags=(--zjit)
  for run in a b; do
    for variant in sym literal; do
      f=$out/$variant.$mode.$run
      VARIANT=$variant MODE=callgrind "$VG_PREFIX/bin/valgrind" --tool=callgrind --instr-atstart=no --smc-check=all-non-file \
        --callgrind-out-file="$f.cg" "$ruby" "${flags[@]}" "$here/ar_read.rb" > "$f.json" 2> "$f.log"
      grep -q "brk segment overflow" "$f.log" && echo "BRK $f"
      ir0=$(awk '/^totals:/ {print $2}' "$f.cg.1"); irn=$(awk '/^totals:/ {print $2}' "$f.cg.2")
      echo "$variant $mode $run Ir/op=$(echo "scale=1; ($irn - $ir0) / $N" | bc) $("$ruby" -rjson -e 'j=JSON.parse(STDIN.read); print "gate=#{j["gate"]} gc=#{j["gc"]}"' < "$f.json")"
    done
  done
done
