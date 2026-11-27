#!/usr/bin/env bash
set -euxo pipefail
root=/home/user/workspace/repo
cache="$root/.amp/in/orb-backup/sq37-review/min-versions"
for side in base head; do
  if [[ $side == base ]]; then sha=088fc0cf61e4ba0c7987decafacc69adb3e22eec; else sha=3e348f32bdc2b5b405d31f226e6de04aa3278dc9; fi
  for sqlite in 3.35.5 3.36.0 3.37.0; do
    env REVIEW_SIDE="$side" BUNDLE_GEMFILE="$cache/trees/$sha/.min-versions/ruby-4.0.9-sqlite-$sqlite/Gemfile" \
      BUNDLE_PATH="$cache/bundle/ruby-4.0.9/sqlite-$sqlite" BUNDLE_WITHOUT=db LD_LIBRARY_PATH="$cache/sqlite-$sqlite/lib" \
      mise exec ruby@4.0.9 -- bundle exec ruby "$root/bench/upstream/sq37/review-thermos-sol-2026-11-25/probe.rb"
  done
  env REVIEW_SIDE="$side" BUNDLE_GEMFILE="$cache/trees/$sha/.min-versions/ruby-4.0.9-sqlite-3.37.0/Gemfile" \
    BUNDLE_PATH="$cache/bundle/ruby-4.0.9/sqlite-3.37.0" BUNDLE_WITHOUT=db LD_LIBRARY_PATH="$cache/sqlite-3.37.0/lib" \
    mise exec ruby@4.0.9 -- bundle exec ruby "$root/.amp/in/orb-backup/sq37-review/boundary_probe.rb"
done
