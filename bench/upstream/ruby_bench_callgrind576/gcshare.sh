#!/usr/bin/env bash
# gcshare.sh FILE...: total Ir (totals line), self Ir in GC files (gc/default/default.c, gc.c) and the rest
for f in "$@"; do
  tot=$(grep -m1 '^totals:' "$f" | cut -d' ' -f2)
  callgrind_annotate --threshold=100 "$f" 2>/dev/null | awk -v f="$(basename $f)" -v tot=$tot '
    /^ *[0-9,]+ +\(/ && !/PROGRAM TOTALS/ { n=$1; gsub(",","",n); if ($0 ~ /gc\/default\/default\.c|\/gc\.c:/) gc+=n }
    END { printf "%s total=%d gc=%d mutator=%d gc%%=%.2f\n", f, tot, gc, tot-gc, 100*gc/tot }'
done
