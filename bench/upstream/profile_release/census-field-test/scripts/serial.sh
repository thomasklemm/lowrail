#!/usr/bin/env bash
# serial.sh: PARALLEL_WORKERS=1 captures (u1..u6 = s1..s6, planted/planted2 = splanted/splanted2) for Hackatime, then
# Writebook, through M4's proof.sh, for the gate design note's one-process-per-capture option.
m4=/home/user/workspace/repo/bench/upstream/profile_release/2026-11-25/scripts
GEM=/home/user/ft/lowrail-profile-0.1.0.rc1.gem
export PARALLEL_WORKERS=1
for app in hackatime writebook; do
  out=/home/user/ft/out/$app-serial
  if [ $app = hackatime ]; then
    APPDIR=/home/user/workspace/repo/.corpus/ft-hackatime
    export PLANT="app/controllers/leaderboards_controller.rb:4a\\    20.times { ERB::Util.html_escape(\"a<b\") }"
    export TEST_DATABASE_URL=postgres://user@localhost/ft_hackatime_test
  else
    APPDIR=/home/user/workspace/repo/.corpus/ft-writebook
    export PLANT="app/controllers/sessions_controller.rb:10a\\    20.times { ERB::Util.html_escape(\"a<b\") }"
  fi
  # First capture alone: if it takes over 15 min, only u2, u3 and planted follow.
  "$m4/proof.sh" "$APPDIR" "$out" "$GEM" u1 -- bin/rails test -v
  w=$(awk '/^u1 exit/ {print int($4)}' "$out/summary.txt")
  if [ "$w" -gt 900 ]; then rest=u2,u3,planted; else rest=u2,u3,u4,u5,u6,planted,planted2; fi
  "$m4/proof.sh" "$APPDIR" "$out" "$GEM" $rest -- bin/rails test -v
  echo "$app done $(date -u +%T)" >> /home/user/ft/serial.log
done
