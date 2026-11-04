#!/usr/bin/env bash
# usage: ractor_each.sh RUBYBIN WORKTREE OUT
# Runs each Ractor test from ractor_names.sh in its own process, so a [BUG]
# abort in one test cannot hide the others.
r=$1 w=$2 out=$3; : > $out
while IFS=$'\t' read -r path rest; do
  comp=${path%%/*}; f=${path#*/}; name=${rest%% = *}
  res=$(cd $w/$comp && PATH=$r:$PATH BUNDLE_PATH=$HOME/src/bundle timeout 120 bundle exec ruby -Itest -Ilib -I../activesupport/lib -I../actionpack/lib -I../actionview/lib -I../activemodel/lib $f -n "/^$(printf '%s' "$name" | sed 's/[][\.*^$?+(){}|/]/\\&/g')\$/" 2>&1)
  st=$?
  sum=$(printf '%s' "$res" | grep -a -E '^[0-9]+ runs' | tail -1)
  bug=$(printf '%s' "$res" | grep -a -o '\[BUG\].\{0,80\}' | head -1)
  err=$(printf '%s' "$res" | grep -a -E -o '(Ractor::[A-Za-z]+Error|[A-Z][A-Za-z:]+Error): [^\n]{0,140}' | grep -v RemoteError | head -1)
  printf '%s\t%s\texit=%s\t%s\t%s\t%s\n' "$path" "$name" "$st" "$sum" "$bug" "$err" >> $out
done < ${NAMES:-/tmp/ractor_names.txt}
