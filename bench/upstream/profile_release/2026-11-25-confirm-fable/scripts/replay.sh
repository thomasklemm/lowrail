#!/usr/bin/env bash
# replay.sh : run_options.sh for the seven sets with the checkout's gem/lib, then what git sees changed.
cd /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-t3
for s in writebook-serial hackatime writebook writebook-w4 campfire-serial osm-serial; do
  /usr/bin/time -f "$s %es" bash scripts/run_options.sh $s
done
git status --short . ; echo "replay done"
