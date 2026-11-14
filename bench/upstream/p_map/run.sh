#!/usr/bin/env bash
# One YJIT profile per app and label, apps in sequence:
#   bench/upstream/p_map/run.sh OUT_DIR LABEL APP...
# OUT_DIR/LABEL/APP.json and .log; refuses to overwrite.
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
out=$1 label=$2; shift 2
mkdir -p "$out/$label"
for app in "$@"; do
  json="$out/$label/$app.json"
  [ -e "$json" ] && { echo "exists: $json" >&2; exit 1; }
  CENSUS_MODE=yjit "$root/bench/upstream/p_map/hx" censuspmap "$app" \
    bundle exec ruby --yjit "$root/bench/upstream/p_map/profile.rb" profile "$app" "$json" > "$out/$label/$app.log" 2>&1 \
    || echo "FAILED $app" >> "$out/$label/$app.log"
done
