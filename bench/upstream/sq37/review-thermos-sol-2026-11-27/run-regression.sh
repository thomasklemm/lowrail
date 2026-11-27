#!/usr/bin/env bash
set -uxo pipefail
root=/home/user/workspace/repo
cache="$root/.amp/in/orb-backup/sq37-review/min-versions"
testfile="$cache/trees/3e348f32bdc2b5b405d31f226e6de04aa3278dc9/activerecord/test/cases/adapters/sqlite3/sqlite3_adapter_test.rb"
for sha in 088fc0cf61e4ba0c7987decafacc69adb3e22eec 3e348f32bdc2b5b405d31f226e6de04aa3278dc9; do
  (
    cd "$cache/trees/$sha/activerecord" || exit
    env BUNDLE_GEMFILE="$cache/trees/$sha/.min-versions/ruby-4.0.9-sqlite-3.37.0/Gemfile" \
      BUNDLE_PATH="$cache/bundle/ruby-4.0.9/sqlite-3.37.0" BUNDLE_WITHOUT=db LD_LIBRARY_PATH="$cache/sqlite-3.37.0/lib" \
      ARCONN=sqlite3 PARALLEL_WORKERS=1 MT_CPU=1 \
      mise exec ruby@4.0.9 -- bundle exec ruby -Itest "$testfile" --name test_check_version_requires_sqlite_3_37 --seed 41231
  )
  echo "REGRESSION_EXIT=$? SHA=$sha"
done
