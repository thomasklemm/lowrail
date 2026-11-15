#!/usr/bin/env bash
# benchmark-ips rounds on one pinned core, settings interleaved, base twice per round (A/A):
#   ips_matrix.sh CORPUS APP WORKLOAD ROUNDS BENCHMARK_IPS_LIB "tags ps cache" ...
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
corpus=$1 app=$2 workload=$3 rounds=$4 lib=$5; shift 5
cfgs=("$@")
for r in $(seq "$rounds"); do
  for cfg in "${cfgs[@]}"; do
    set -- $cfg
    echo "=== $corpus $app $workload $1/$2/$3${4:+ $4} round $r"
    QLT_CONFIG=$here/config.rb QLT_TAGS=$1 QLT_PS=$2 QLT_CACHE=$3 CENSUS_MODE=yjit \
      "$here/../p_map/hx" "$corpus" "$app" taskset -c 1 bundle exec ruby --yjit -I "$lib" "$here/ips.rb" "$app" "$workload" 2>&1 \
      | grep -E "^ruby |i/s"
  done
done
