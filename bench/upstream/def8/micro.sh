#!/usr/bin/env bash
# Interpreter instructions and objects per call of each case (subtract noop):
#   micro.sh APP_DIR SCRIPT N CASE...
app=$1 script=$2 n=$3; shift 3
cd "$app"
for c in "$@"; do
  out=$(DEF8_INTERP=1 valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle --callgrind-out-file=/dev/null ruby -rbundler/setup "$script" "$c" "$n" 2>&1)
  ir=$(grep -o 'Collected : [0-9]*' <<<"$out" | grep -o '[0-9]*$'); obj=$(grep -o 'objects=[0-9.]*' <<<"$out")
  echo "$c $(( ir / n )) $obj"
done
