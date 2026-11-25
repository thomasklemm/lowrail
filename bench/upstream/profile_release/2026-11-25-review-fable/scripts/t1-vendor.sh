#!/usr/bin/env bash
# t1-vendor.sh RUBY SRC DIR : the T1 app with its bundle in vendor/bundle (BUNDLE_PATH inside the root).
set -euo pipefail
. "$(dirname "$0")/env.sh" "$1"
rm -rf "$3"; cp -a "$2" "$3"; cd "$3"; rm -rf tmp/lowrail-profile
bundle config set --local path vendor/bundle
# The release candidate is not on rubygems.org: the unpacked built gem, from a path.
ruby -pi -e 'sub(/^gem "lowrail-profile".*$/, %(gem "lowrail-profile", path: "/tmp/pr/unpacked/lowrail-profile-0.1.0.rc1", group: [:development, :test], require: false))' Gemfile
bundle install >/dev/null
PARALLEL_WORKERS=1 bundle exec lowrail-profile --keep-runs --top 400 -- bin/rails test test/controllers test/integration/many_test.rb > /tmp/pr/t1v-run.log 2>&1; echo "exit $?"
grep -n "Not attributed" tmp/lowrail-profile/report.md | cut -c1-400
ruby "$(dirname "$0")/t1-report.rb" tmp/lowrail-profile/report.json | grep -v "^groups\|^controller"
ruby -rjson -e 'r=JSON.parse(File.read("tmp/lowrail-profile/report.json")); puts r["groups"].map { _1["group"] }.sort.join(", "); puts r["ranked"].map { _1["site"] }.grep_v(/\A(RAILS|GEM|RUBY)\//).first(5).inspect; puts r["app_lines"].map { _1["line"] }.grep(/vendor|gems/).inspect'
git status --porcelain | head
