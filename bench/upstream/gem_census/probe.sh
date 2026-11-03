#!/usr/bin/env bash
# Runs site_callers.rb in census copies, under the variant bundle at the pin:
#   SITES="gem/path.rb:LINE,..." bench/upstream/gem_census/probe.sh APP...
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
sha=3bdc57909066eb17dee70fea0b6266edaffa9ffc
for app in "$@"; do
  copy=${app%-nops}
  dir=$root/.corpus/census-$copy
  env=$(cd "$root" && ruby -e 'load "script/census"; puts Census::APPS.fetch(ARGV[0]).fetch(:env, {}).map { |k, v| "#{k}=#{v}" }' "$app")
  echo "### $app"
  (cd "$dir" && env $env BUNDLE_GEMFILE="$dir/Gemfile.census-${sha:0:12}" RAILS_ENV=production RACK_ENV=production \
    SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=fatal CENSUS_RAILS_SHA=$sha CENSUS_MODE=interpreter RUBY_YJIT_ENABLE=0 \
    bundle exec ruby "$root/bench/upstream/gem_census/site_callers.rb" "$app" 2>/dev/null | grep -A"${TOP:-5}" "^== ")
done
