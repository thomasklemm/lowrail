#!/usr/bin/env bash
# One page wall lane for TO1: APP in MODE (yjit on 4.0.10, zjit on master), rounds FIRST..LAST, pinned to CPU.
# A round is three fresh processes: Rails main twice (a, b: the A/A) and the TO1 head once (h), in the six
# orders of a/h/b in turn. Each is `script/census run --wall --only WORKLOAD` (census-3 method, GC on).
#   to1_wall_lane.sh APP MODE CPU FIRST LAST
set -uo pipefail
app=$1 mode=$2 cpu=$3 first=$4 last=$5
root=/home/user/workspace/repo
out=$root/bench/upstream/to1-open-2026-11-27/page/wall/$app-$mode
main=rails/rails@2e299253f942ab94041cc6f210ac9d33884c210d
head=thomasklemm/rails@18fd3c4a07ad33c24bf7b3bd3b4bb302ec91ab08
case $app in
  blog) only="GET article"; export CENSUS_WALL_CYCLES=25 CENSUS_WALL_WARM=80 ;;
  writebook) only="GET books"; export CENSUS_WALL_CYCLES=15 CENSUS_WALL_WARM=80 ;;
  casa) only="GET casa case edit"; export CENSUS_WALL_CYCLES=3 CENSUS_WALL_WARM=150 ;;
esac
export CENSUS_WALL_WINDOWS=20 RUBY_GC_HEAP_INIT_BYTES=33554432
if [ "$mode" = zjit ]; then ruby=$HOME/rubies/master-0d399335b7/bin; wall="--zjit-exec-mem-size=512 --zjit-mem-size=1024"
else ruby=$(~/.local/bin/mise where ruby@4.0.10)/bin; wall=""; fi
export PATH=$(~/.local/bin/mise where ruby@4.0.10)/bin:$PATH
mkdir -p "$out"
orders=("a h b" "a b h" "h a b" "h b a" "b a h" "b h a")
for r in $(seq "$first" "$last"); do
  n=$(printf %02d "$r")
  for p in ${orders[$(( (r - 1) % 6 ))]}; do
    label=r$n-$p
    [ -f "$out/$label/$app-$mode.json" ] && continue
    rails=$main; [ $p = h ] && rails=$head
    s=$(date +%s)
    (cd "$root" && taskset -c "$cpu" script/census run --label "$label" --corpus censusto1 --rails "$rails" --ruby "$ruby" \
      --modes "$mode" --apps "$app" --only "$only" --wall="$wall" --out "$out" > "$out/$label.log" 2>&1)
    echo "$(date +%T) $app $mode $label exit $? $(( $(date +%s) - s ))s $(grep -o '"gate": "[a-z/]*"' "$out/$label/$app-$mode.json" 2>/dev/null)"
  done
done
echo "$app $mode done $(date +%T)"
