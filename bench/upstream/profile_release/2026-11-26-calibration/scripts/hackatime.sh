#!/usr/bin/env bash
# Hackatime: plain once, 8 unchanged one-process captures, 2 planted, through M4's proof.sh as the census field test
# (T-01a2142d serial.sh). Resumable: steps with a line in summary.txt are skipped.
set -u
repo=/home/user/workspace/repo app=$repo/.corpus/ft-hackatime out=/home/user/cal/out/hackatime
export PARALLEL_WORKERS=1 TEST_DATABASE_URL=postgres:///ft_hackatime_test
file=app/controllers/leaderboards_controller.rb
export PLANT="$file:4a\\    20.times { ERB::Util.html_escape(\"a<b\") }"
for s in plain s1 s2 s3 s4 s5 s6 s7 s8 planted planted2; do
  grep -q "^$s exit" "$out/summary.txt" 2>/dev/null && continue
  git -C "$app" checkout -q -- "$file"
  "$repo/bench/upstream/profile_release/2026-11-25/scripts/proof.sh" "$app" "$out" \
    /home/user/cal/gem/lowrail-profile-0.1.0.rc1.gem $s -- bin/rails test -v
done
grep -q "ALL DONE" "$out/summary.txt" || echo ALL DONE >> "$out/summary.txt"
exec sleep infinity
