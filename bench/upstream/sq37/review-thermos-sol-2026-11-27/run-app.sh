#!/usr/bin/env bash
set -uxo pipefail
root=/home/user/workspace/repo
cache="$root/.amp/in/orb-backup/sq37-review/min-versions"
for sha in 088fc0cf61e4ba0c7987decafacc69adb3e22eec 3e348f32bdc2b5b405d31f226e6de04aa3278dc9; do
  for sqlite in 3.36.0 3.37.0; do
    env -u DATABASE_URL BUNDLE_GEMFILE="$cache/trees/$sha/.min-versions/ruby-4.0.9-sqlite-$sqlite/Gemfile" \
      BUNDLE_PATH="$cache/bundle/ruby-4.0.9/sqlite-$sqlite" BUNDLE_WITHOUT=db LD_LIBRARY_PATH="$cache/sqlite-$sqlite/lib" \
      RAILS_ENV=development REVIEW_DATABASE="$root/.amp/in/orb-backup/sq37-review/app/$sha-$sqlite.sqlite3" \
      mise exec ruby@4.0.9 -- ruby bin/rails db:prepare
    echo "APP_EXIT=$? SHA=$sha SQLITE=$sqlite"
  done
done
