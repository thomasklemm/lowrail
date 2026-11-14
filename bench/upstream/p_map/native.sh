#!/usr/bin/env bash
# Native perf profile of one app's measured windows (Vernier off):
#   bench/upstream/p_map/native.sh OUT_DIR LABEL APP
# Writes OUT_DIR/LABEL/APP.native.json (windows), APP.perf.data and APP.perf.txt
# (perf report: comm, dso, symbol; no children).
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
out=$1/$2 app=$3
mkdir -p "$out"
[ -e "$out/$app.perf.data" ] && { echo "exists: $out/$app.perf.data" >&2; exit 1; }
fifo=$(mktemp -d)
mkfifo "$fifo/ctl" "$fifo/ack"
chmod 666 "$fifo/ctl" "$fifo/ack"
CENSUS_MODE=yjit "$root/bench/upstream/p_map/hx" censuspmap "$app" \
  bundle exec ruby --yjit --yjit-perf "$root/bench/upstream/p_map/native.rb" "$app" "$out/$app.native.json" "$fifo/ctl" "$fifo/ack" \
  > "$out/$app.native.log" 2>&1 &
pid=$!
sudo perf record -e cpu-clock -F 997 -p "$pid" -D -1 --control "fifo:$fifo/ctl,$fifo/ack" -o "$out/$app.perf.data" \
  > "$out/$app.perf.log" 2>&1 &
wait "$pid"
sudo chown "$USER" "$out/$app.perf.data"
sleep 1
perf report -i "$out/$app.perf.data" --stdio --no-children --sort comm,dso,sym --percent-limit 0 2>/dev/null \
  | grep -v '^#' | grep -v '^$' > "$out/$app.perf.txt"
rm -rf "$fifo"
