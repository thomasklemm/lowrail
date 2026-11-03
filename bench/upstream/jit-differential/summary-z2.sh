#!/bin/bash
source ~/jitdiff/env.sh m2
for d in ~/jitdiff/out/m2/*/ ~/jitdiff/out/m2-main/*/ ~/jitdiff/out/m2dbg/*/ ~/jitdiff/out/m2dbg-main/*/; do
  [ -d "$d" ] || continue
  r=$(ruby ~/jitdiff/compare.rb $d 2>&1)
  echo "## ${d#$HOME/jitdiff/out/} $(echo "$r" | grep -c 'tests, 0 result diffs') clean"
  echo "$r" | grep -v "tests, 0 result diffs" | head -${1:-12}
done
