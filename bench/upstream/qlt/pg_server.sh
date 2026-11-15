#!/usr/bin/env bash
# PostgreSQL backend CPU per request (probe.rb's db_backend_us), settings interleaved:
#   pg_server.sh CORPUS APP WORKLOAD N ROUNDS >> OUT.jsonl
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
corpus=$1 app=$2 workload=$3 n=$4 rounds=$5
for r in $(seq "$rounds"); do
  for cfg in "none on 0" "default off 0" "default off 1" "default on 0" "request_id off 1" "request_id on 1"; do
    set -- $cfg
    QLT_CONFIG=$here/config.rb QLT_TAGS=$1 QLT_PS=$2 QLT_CACHE=$3 CENSUS_MODE=yjit \
      "$here/../p_map/hx" "$corpus" "$app" taskset -c 1 bundle exec ruby --yjit "$here/probe.rb" "$app" "$workload" "$n" 2>&1 | grep '^{' \
      | sed "s/^{/{\"round\":$r,/"
  done
done
