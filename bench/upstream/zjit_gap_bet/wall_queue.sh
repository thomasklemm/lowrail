#!/usr/bin/env bash
# One timing lane for bench/upstream/zjit_gap_bet/HANDOFF.md.
#   wall_queue.sh OUT CPU TARGET FIRST_ROUND LAST_ROUND
# TARGET: railsbench, lobsters, shipit (ruby-bench on Rails main) or campfire, writebook (census copies, corpus
# censusz3). A round is five fresh processes pinned to CPU: master YJIT and ZJIT twice each (the twins are the A/A)
# and the headline branch's ZJIT once, in the order Y Z H Z Y in odd rounds and Z Y H Y Z in even ones.
# Env: MASTER and HEADLINE (prefixes under ~/rubies), WARMUP_ITRS/MEASURE_ITRS (ruby-bench),
# CENSUS_WALL_WARM/CENSUS_WALL_WINDOWS/CENSUS_WALL_CYCLES (census).
set -uo pipefail
out=$1 cpu=$2 target=$3 first=$4 last=$5
root=$(cd "$(dirname "$0")/../../.." && pwd)
master=$HOME/rubies/${MASTER:-master-0d399335b7} headline=$HOME/rubies/${HEADLINE:-h6-5c4239a16d}
Z="--zjit-exec-mem-size=512 --zjit-mem-size=1024"
export WARMUP_ITRS=${WARMUP_ITRS:-150} MEASURE_ITRS=${MEASURE_ITRS:-20}
export CENSUS_WALL_WARM=${CENSUS_WALL_WARM:-80} CENSUS_WALL_WINDOWS=${CENSUS_WALL_WINDOWS:-20} CENSUS_WALL_CYCLES=${CENSUS_WALL_CYCLES:-5}
export RUBY_GC_HEAP_INIT_BYTES=33554432
# Writebook's "POST page" adds a page per cycle, and every later request then renders a longer book.
[ "$target" = writebook ] && export CENSUS_WALL_SKIP="POST page (turbo_stream)"
base=$("$HOME/.local/bin/mise" where ruby@4.0.9)/bin
mkdir -p "$out/$target"

one() { # NAME PREFIX MODE
  local name=$1 prefix=$2 mode=$3 json=$out/$target/$1.json s
  [ -f "$json" ] && { echo "skip $target $name"; return; }
  s=$(date +%s)
  case $target in
  campfire|writebook)
    local copy=$root/.corpus/censusz3-$target
    rm -rf "$copy/storage" && cp -a "$copy/storage.pristine" "$copy/storage"
    (cd "$root" && PATH=$base:$PATH taskset -c "$cpu" script/census run --label "$name" --corpus censusz3 --ruby "$prefix/bin" \
      --modes "$mode" --apps "$target" --wall="$Z" --out "$out/$target/census" > "$out/$target/$name.log" 2>&1)
    local rc=$?
    [ -f "$out/$target/census/$name/$target-$mode.json" ] && cp "$out/$target/census/$name/$target-$mode.json" "$json"
    ;;
  *)
    if [ "$mode" = zjit ]; then "$root/bench/upstream/zjit_gap_bet/wall_run.sh" "$target" "$prefix" "$json" "$cpu" --zjit $Z
    else "$root/bench/upstream/zjit_gap_bet/wall_run.sh" "$target" "$prefix" "$json" "$cpu" --yjit; fi
    local rc=$?
    ;;
  esac
  echo "$(date +%T) $target $name exit $rc $(( $(date +%s) - s ))s $(grep -o '"gate": "[a-z/]*"' "$json" 2>/dev/null)"
}

for r in $(seq "$first" "$last"); do
  n=$(printf %02d "$r")
  if (( r % 2 )); then order=(yjit-a zjit-a h zjit-b yjit-b); else order=(zjit-a yjit-a h yjit-b zjit-b); fi
  for p in "${order[@]}"; do
    case $p in
      h) one "r$n-hzjit" "$headline" zjit ;;
      yjit-*) one "r$n-$p" "$master" yjit ;;
      zjit-*) one "r$n-$p" "$master" zjit ;;
    esac
  done
done
echo "$target done $(date +%T)"
