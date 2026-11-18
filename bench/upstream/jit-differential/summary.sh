#!/bin/bash
export PATH=$HOME/rubies/master/bin:$PATH
cd ~/jitdiff
for d in out/*/*/; do
  [ -d "$d" ] || continue
  case $d in */ruby-*) r=$(ruby rcompare.rb $d 2>&1); c=$(echo "$r" | grep -c ' 0 diffs');;
    *) r=$(ruby compare.rb $d 2>&1); c=$(echo "$r" | grep -c 'tests, 0 result diffs');; esac
  echo "## ${d#out/} $c clean of $(ls $d/*.log 2>/dev/null | wc -l) logs"
  echo "$r" | grep -v -E ' 0 diffs|tests, 0 result diffs' | head -${1:-12}
done
