#!/bin/bash
# census_3_profile.sh APP MODE OUTPUT_DIR — one fresh production-mode profile process.
set -e
root=/home/user/workspace/repo
n=$1; mode=$2; out=$3
cd $root/.corpus/census3-$n
export BUNDLE_FROZEN=true RAILS_ENV=production RACK_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=fatal DATABASE_ADAPTER=sqlite SKIP_TELEMETRY=1 APP_VERSION=census RUBY_YJIT_ENABLE=0 RUBY_ZJIT_ENABLE=0 CENSUS_MODE=$mode
unset RUBYOPT
flags=""; [ $mode = yjit ] && flags=--yjit
mise exec -- bundle exec ruby $flags $root/bench/upstream/rails_main_census.rb profile $n $out/$n-$mode.json
