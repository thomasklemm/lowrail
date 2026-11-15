#!/usr/bin/env bash
# One jit_stats.rb run: bench/upstream/vm1/stats.sh OUT_DIR CORPUS APP LABEL RUBY_FLAGS...
# OUT_DIR/LABEL/APP.json and .log; refuses to overwrite. VM1_RUBY picks the Ruby (see hx).
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
mkdir -p "$1/$4"
out=$(cd "$1" && pwd) corpus=$2 app=$3 label=$4; shift 4
json="$out/$label/$app.json"
[ -e "$json" ] && { echo "exists: $json" >&2; exit 1; }
mode=$([[ " $* " == *" --zjit"* ]] && echo zjit || echo yjit)
VM1_FLAGS="$*" CENSUS_MODE=$mode "$root/bench/upstream/vm1/hx" "$corpus" "$app" \
  bundle exec ruby "$@" "$root/bench/upstream/vm1/jit_stats.rb" "$app" "$json" > "$out/$label/$app.log" 2>&1 \
  || { echo "FAILED $app" >> "$out/$label/$app.log"; exit 1; }
tail -1 "$out/$label/$app.log"
