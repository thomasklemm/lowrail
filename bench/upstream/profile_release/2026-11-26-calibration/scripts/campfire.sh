#!/usr/bin/env bash
# Campfire: plain once, 8 unchanged one-process captures, 2 with the M4 plant, through M4's proof.sh as
# 2026-11-25-t3/scripts/serial.sh does. Resumable: steps with a line in summary.txt are skipped.
set -u
repo=/home/user/workspace/repo app=$repo/.corpus/rc-campfire out=/home/user/cal/out/campfire
export PARALLEL_WORKERS=1
file=app/controllers/rooms_controller.rb
export PLANT="$file:11a\\    20.times { ERB::Util.html_escape(\"a<b\") }"
for s in plain s1 s2 s3 s4 s5 s6 s7 s8 planted planted2; do
  grep -q "^$s exit" "$out/summary.txt" 2>/dev/null && continue
  git -C "$app" checkout -q -- "$file"
  "$repo/bench/upstream/profile_release/2026-11-25/scripts/proof.sh" "$app" "$out" \
    /home/user/cal/gem/lowrail-profile-0.1.0.rc1.gem $s -- bin/rails test -v
done
grep -q "ALL DONE" "$out/summary.txt" || echo ALL DONE >> "$out/summary.txt"
exec sleep infinity
