#!/usr/bin/env bash
# assemble.sh APP...: copy one app's field-test outputs from /home/user/ft/out/APP into the record
# (bench/upstream/profile_release/census-field-test/apps/APP): the small text receipts, plus
# reports.tar.xz with every capture's report.json, command.txt and capture.json (raw TSV runs are not kept).
set -eu
rec=/home/user/workspace/repo/bench/upstream/profile_release/census-field-test/apps
for app in "$@"; do
  src=/home/user/ft/out/$app dst=$rec/$app
  rm -rf "$dst"; mkdir -p "$dst"
  for f in summary.txt outcomes.txt features.txt features-parallel.txt exits.txt overhead.txt margin.txt \
           timeline.txt installed-from.txt planted.patch planted2.patch compare-noaa.md compare-seed99.md \
           cijob-unchanged-1.md cijob-unchanged-2.md cijob-planted-1.md cijob-planted-2.md report-again.err; do
    [ -f "$src/$f" ] && cp "$src/$f" "$dst/"
  done
  for f in "$src"/gate*.txt; do [ -f "$f" ] && cp "$f" "$dst/"; done
  # plant patches: only the hunks under app/ (the checkout's setup diff is not the plant)
  for p in "$dst"/planted*.patch; do
    [ -f "$p" ] || continue
    awk '/^diff --git/ { keep = ($3 ~ /^a\/(app|lib)\//) } keep' "$p" > "$p.tmp" && mv "$p.tmp" "$p"
  done
  ( cd "$src" && files=$(ls -d */report.json */command.txt */capture.json 2>/dev/null | grep -v '^cache/') \
    && tar cf - $files | xz -9 -T8 > "$dst/reports.tar.xz" )
  du -sh "$dst" | tr '\n' ' '; echo
done
