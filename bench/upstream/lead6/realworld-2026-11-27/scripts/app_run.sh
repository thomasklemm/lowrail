#!/bin/bash
# app_run.sh ARM MODE [ruby flags...]: runs app_time.rb in the hackatime census copy.
# ARM: main | main2 (same Rails commit, A/A) | l6 | VARIANT_SHA12 (Gemfile.census-SHA12 in the copy)
set -e
arm=$1; mode=$2; shift 2
copy=/home/user/workspace/repo/.corpus/censusl6rw-hackatime
case $arm in
  main|main2) sha=088fc0cf61e4ba0c7987decafacc69adb3e22eec ;;
  l6) sha=8b1c6428ea056b3c5983372d85b85615ae3d3f45 ;;
  fix) sha=298a1f4a13a9aa75fb3a57a5b3b8ee187c85c49f ;;
  fix2) sha=4e635c7ca5aa5e66f51bbf6b1c5b9c9ae3a0ed57 ;;
  *) sha=$(cat $copy/Gemfile.census-$arm.sha) ;;
esac
ruby=$(mise where ruby@4.0.10)/bin/ruby
flags=()
[ "$mode" = yjit ] && flags=(--yjit)
cd $copy
exec env -u RUBYOPT -u GEM_HOME -u GEM_PATH PATH=$(dirname $ruby):$PATH BUNDLE_GEMFILE=$copy/Gemfile.census-${sha:0:12} BUNDLE_FROZEN=true \
  RAILS_ENV=production RACK_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=fatal SKIP_TELEMETRY=1 APP_VERSION=census \
  APP_HOST=localhost RUBY_YJIT_ENABLE=0 CENSUS_RAILS_SHA=$sha DISABLE_DATABASE_ENVIRONMENT_CHECK=1 CENSUS_MODE=$( [ "$mode" = yjit ] && echo yjit || echo interpreter ) \
  POOL_DATABASE_URL=postgres:///census_hackatime DATABASE_URL=postgres:///census_hackatime_cache \
  ENCRYPTION_PRIMARY_KEY=censusprimarykeycensusprimarykey ENCRYPTION_DETERMINISTIC_KEY=censusdeterministiccensusdetermi \
  ENCRYPTION_KEY_DERIVATION_SALT=censussaltcensussaltcensussalt12 S3_ACCESS_KEY_ID=census S3_SECRET_ACCESS_KEY=census \
  S3_BUCKET=census S3_ENDPOINT=http://127.0.0.1:9 AWS_EC2_METADATA_DISABLED=true ARM=$arm \
  taskset -c ${CPU:-1} $ruby "${flags[@]}" "$@" -rbundler/setup /home/user/workspace/repo/.amp/in/orb-backup/l6rw/app_time.rb
