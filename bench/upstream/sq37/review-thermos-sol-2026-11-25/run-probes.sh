#!/usr/bin/env bash
set -eu
root=/home/user/workspace/repo
cache="$root/.amp/in/orb-backup/sq37-review/min-versions"
for sha in f785381cca8621772cba659ff93f825eb7f99942 183262f44056c9b860cb0921b2c596a2e183653d; do
  for sqlite in 3.35.5 3.36.0 3.37.0; do
    echo "--- $sha / SQLite $sqlite ---"
    env BUNDLE_GEMFILE="$cache/trees/$sha/.min-versions/ruby-4.0.9-sqlite-$sqlite/Gemfile" \
      BUNDLE_PATH="$cache/bundle/ruby-4.0.9/sqlite-$sqlite" BUNDLE_WITHOUT=db \
      LD_LIBRARY_PATH="$cache/sqlite-$sqlite/lib" \
      mise exec ruby@4.0.9 -- bundle exec ruby "$root/.amp/in/orb-backup/sq37-review/probe.rb"
  done
done
