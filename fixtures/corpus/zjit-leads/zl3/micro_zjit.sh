#!/bin/bash
# micro_zjit.sh OUT LABEL CASE [K [P]] : fixtures/corpus/zjit-leads/micro.rb under ZJIT (or MODE_FLAGS), runs a and b
# (A/A) under the pinned Callgrind, plus one stats run. RUBY_PREFIX selects the build, CG_EXT_DIR its extension.
set -uo pipefail
out=$1 label=$2; shift 2
micro=/home/user/workspace/repo/fixtures/corpus/zjit-leads/micro.rb
ruby=$RUBY_PREFIX/bin/ruby
flags=(${MODE_FLAGS:---zjit})
export CG_EXT_DIR RUBY_GC_HEAP_INIT_BYTES=33554432 N=${N:-100000}
mkdir -p "$out"
tag=$(IFS=-; echo "$*")
for run in a b; do
  f=$out/$tag.$label.$run
  MODE=callgrind /home/user/w/vg/bin/valgrind --tool=callgrind --instr-atstart=no --smc-check=all-non-file --callgrind-out-file="$f.cg" \
    "$ruby" --disable-gems "${flags[@]}" "$micro" "$@" > "$f.json" 2> "$f.log"
  grep -q "brk segment overflow" "$f.log" && echo "BRK $f"
  ir0=$(awk '/^totals:/ {print $2}' "$f.cg.1"); irn=$(awk '/^totals:/ {print $2}' "$f.cg.2")
  echo "$tag $label $run Ir/call=$(echo "scale=1; ($irn - $ir0) / $N" | bc) $("$ruby" -rjson -e 'j=JSON.parse(STDIN.read); print "gate=#{j["gate"]} gc=#{j["gc"]} after=#{j["after"]}"' < "$f.json")"
  rm -f "$f.cg".*
done
s=(--zjit-stats-quiet); [[ ${flags[0]} == --yjit ]] && s=(--yjit-stats=quiet)
"$ruby" --disable-gems "${flags[@]}" "${s[@]}" "$micro" "$@" > "$out/$tag.$label.stats.json"
