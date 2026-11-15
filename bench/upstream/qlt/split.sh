#!/usr/bin/env bash
# Callgrind self instructions per request, split by object (SQLite engine and driver vs the rest),
# for one query log tag setting, interpreter:
#   QLT_TAGS=.. QLT_PS=.. QLT_CACHE=.. split.sh CORPUS APP WORKLOAD N
# Prints: APP|WORKLOAD|tags/ps/cache|total Ir per request|sqlite3_native.so Ir per request
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
corpus=$1 app=$2 workload=$3 n=$4
out=$(mktemp)
QLT_CONFIG=$here/config.rb CENSUS_MODE=interpreter "$here/../p_map/hx" "$corpus" "$app" \
  valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle --callgrind-out-file="$out" \
  ruby -rbundler/setup "$here/../p_map/request_ir.rb" "$app" "$workload" "$n" > /dev/null 2>&1
callgrind_annotate --inclusive=no --threshold=100 "$out" 2>/dev/null | awk -v n="$n" -v id="$app|$workload|${QLT_TAGS}/${QLT_PS}/${QLT_CACHE:-0}" '
  /PROGRAM TOTALS/ { gsub(",", "", $1); total = $1 }
  /sqlite3_native\.so\]$/ { gsub(",", "", $1); sqlite += $1 }
  END { printf "%s|%d|%d\n", id, total / n, sqlite / n }'
rm -f "$out"
