#!/usr/bin/env bash
# Best of ROUNDS benchmark-ips runs of one census request per tree, on one pinned core,
# trees in a palindromic order rotated by round (base, branch, base again as A/A):
#   page_ips.sh OUT CORPUS APP WORKLOAD MODE BRANCH_SPEC [ROUNDS] [CPU]   MODE: interp | yjit
# OUT gets every run's raw output; the summary line per tree is "TREE best i/s".
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
out=$1 corpus=$2 app=$3 workload=$4 mode=$5 branch=$6 rounds=${7:-5} cpu=${8:-3}
ips=$(ls -d "$root"/.lowrail/private/pmap/gems/gems/benchmark-ips-*/lib | tail -1)
flag=(); [ "$mode" = yjit ] && flag=(--yjit)
run() {
  local tree=$1 spec=""
  [ "$tree" = branch ] && spec=$branch
  echo "### $tree round $2" >> "$out"
  CENSUS_MODE=$([ "$mode" = yjit ] && echo yjit || echo interpreter) PMAP_RAILS=$spec \
    taskset -c "$cpu" "$root/bench/upstream/p_map/hx" "$corpus" "$app" \
    bundle exec ruby "${flag[@]}" -I "$ips" "$root/bench/upstream/qb/page_ips.rb" "$app" "$workload" 2>&1 \
    | grep -E "i/s|compiled_blocks|ruby " >> "$out"
}
for r in $(seq 1 "$rounds"); do
  if (( r % 2 )); then order=(base branch aa); else order=(aa branch base); fi
  for t in "${order[@]}"; do run "$t" "$r"; done
done
for t in base aa branch; do
  best=$(awk -v t="$t" '/^### /{cur=$2} cur==t && /i\/s/' "$out" | grep -oP '[0-9.]+k?(?=\s+\(±)' \
    | sed 's/k$/*1000/' | bc | sort -n | tail -1)
  echo "$t $best"
done
