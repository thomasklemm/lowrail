#!/usr/bin/env bash
set -u
root=/home/user/workspace/repo
cache="$root/.amp/in/orb-backup/sq37-review/min-versions"
for sha in f785381cca8621772cba659ff93f825eb7f99942 183262f44056c9b860cb0921b2c596a2e183653d; do
  for sqlite in 3.36.0 3.37.0; do
    echo "--- $sha / SQLite $sqlite ---"
    env -u DATABASE_URL BUNDLE_GEMFILE="$cache/trees/$sha/.min-versions/ruby-4.0.9-sqlite-$sqlite/Gemfile" \
      BUNDLE_PATH="$cache/bundle/ruby-4.0.9/sqlite-$sqlite" BUNDLE_WITHOUT=db \
      LD_LIBRARY_PATH="$cache/sqlite-$sqlite/lib" RAILS_ENV=development \
      REVIEW_DATABASE="$root/.amp/in/orb-backup/sq37-review/app/$sha-$sqlite.sqlite3" \
      mise exec ruby@4.0.9 -- ruby bin/rails db:prepare
    echo "exit=$?"
  done
done
