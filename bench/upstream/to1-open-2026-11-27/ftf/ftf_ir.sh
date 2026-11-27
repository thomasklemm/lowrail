#!/usr/bin/env bash
# Usage: ftf_ir.sh RAILS LABEL OUT; interpreter, Ruby on PATH, fixed heap as bench.md.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); rails=$1; label=$2; out=$3; N=${N:-2000}
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
unset RUBYOPT
mkdir -p "$out/raw"
for c in "f.text_field" "f.text_field class+placeholder" "f.text_field data" "f.text_field long value" "text_field_tag" "tag.input 5 attrs"; do
  slug=$(echo "$c" | tr ' +.' '___')
  for k in $N 0; do
    f="$out/raw/$label-$slug-$k.cg"
    valgrind --tool=callgrind --toggle-collect=rb_ary_cycle --callgrind-out-file="$f" ruby "$here/ftf_ir.rb" "$rails" "$c" "$k" 2>/dev/null
  done
  a=$(grep -m1 '^totals:\|^summary:' "$out/raw/$label-$slug-$N.cg" | awk '{print $2}'); b=$(grep -m1 '^totals:\|^summary:' "$out/raw/$label-$slug-0.cg" | awk '{print $2}')
  echo -e "$label\t$c\t$(( (a - b) / N ))"
done
