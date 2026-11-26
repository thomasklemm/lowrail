#!/usr/bin/env bash
# build-unbundled.sh : the counter built from an empty cache under `bundle exec` (60387485 builds it outside the
# bundle). A copy of the fresh app whose Gemfile reads .ruby-version relative to the cwd, as Dawarich's does, on Ruby
# 4.0.7 with the installed gem and with the exe of 1618fc38; the RSpec app on Ruby 3.3.14.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
(
  . "$here/../env.sh" 4.0.7; cd /tmp/pr2/gemsapp
  printf '4.0.7\n' > .ruby-version; grep -q 'File.read(".ruby-version")' Gemfile || printf '\nruby File.read(".ruby-version").strip\n' >> Gemfile
  bundle lock --local > /tmp/pr2/build-lock.log 2>&1; echo "bundle lock --local: exit $?"
  for exe in installed /tmp/pr2/old/gem/exe/lowrail-profile; do
    rm -rf /tmp/pr2/cache-b
    if [ $exe = installed ]; then XDG_CACHE_HOME=/tmp/pr2/cache-b PARALLEL_WORKERS=1 bundle exec lowrail-profile --out tmp/lp-b -- bin/rails test test/integration/gems_test.rb > /tmp/pr2/build-b.log 2>&1
    else XDG_CACHE_HOME=/tmp/pr2/cache-b PARALLEL_WORKERS=1 bundle exec ruby $exe --out tmp/lp-b -- bin/rails test test/integration/gems_test.rb > /tmp/pr2/build-b.log 2>&1; fi
    status=$?
    echo "Ruby 4.0.7, Gemfile reads .ruby-version, $([ $exe = installed ] && echo 60387485 || echo 1618fc38): exit $status; counters built: $(find /tmp/pr2/cache-b -name 'lowrail_profile.so' | wc -l); $(grep -E 'Counted|building the counter failed' /tmp/pr2/build-b.log | cut -c1-90)"
    grep -h "ruby-version" /tmp/pr2/cache-b/lowrail/profile/*/*.build.log 2>/dev/null | head -1 | cut -c1-200
  done
)
(
  . "$here/../env.sh" 3.3.14; cd /tmp/pr/a72/rspec; rm -rf /tmp/pr2/cache-b
  XDG_CACHE_HOME=/tmp/pr2/cache-b bundle exec lowrail-profile --out tmp/lp-b -- rspec spec/requests > /tmp/pr2/build-b.log 2>&1
  echo "Ruby 3.3.14, RSpec app, 60387485: exit $?; counters built: $(find /tmp/pr2/cache-b -name 'lowrail_profile.so' | wc -l); $(grep -E 'Counted|building the counter failed' /tmp/pr2/build-b.log | cut -c1-90)"
  rm -rf tmp/lp-b; git checkout -q swagger; git status --short
)
