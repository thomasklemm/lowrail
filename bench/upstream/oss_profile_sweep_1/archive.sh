#!/usr/bin/env bash
# archive.sh: copies each capture's report.md, capture.json, command.txt and gzipped report.json, plus the
# per-test outcome lists, tree diffs, compare outputs and log tails, from /home/user/oss into this directory.
set -u
here=$(cd "$(dirname "$0")" && pwd)
oss=/home/user/oss
declare -A dirs=([redmine]=redmine [solidus]=solidus/api [huginn]=huginn [forem]=forem [dawarich]=dawarich [osm]=openstreetmap-website)
for app in "${!dirs[@]}"; do
  src=$oss/${dirs[$app]}/tmp
  for cap in "$src"/lowrail-profile*; do
    [ -f "$cap/report.json" ] || continue
    name=$(basename "$cap"); name=${name#lowrail-profile}; name=${name#-}; name=${name:-base}
    dst=$here/$app/$name; mkdir -p "$dst"
    cp "$cap"/report.md "$cap"/capture.json "$cap"/command.txt "$dst"/
    gzip -9c "$cap/report.json" > "$dst/report.json.gz"
  done
  for f in "$oss"/logs/$app-*; do
    case $f in
      *.log) tail -n 40 "$f" > "$here/$app/$(basename "$f" .log).tail.txt" ;;
      *-tree-*) gzip -9c "$f" > "$here/$app/$(basename "$f").gz" ;;
      *-out-*|*-compare*|*-paths.txt|*.patch) cp "$f" "$here/$app/" ;;
    esac
  done
done
