#!/bin/bash
# prep.sh APP  -- database, data and assets for a census4 copy (Ruby 4.0.7)
set -euo pipefail
root=/home/user/workspace/repo
n=$1
dir=$root/.corpus/census4-$n
export BUNDLE_FROZEN=true RAILS_ENV=production RACK_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=fatal SKIP_TELEMETRY=1 APP_VERSION=census APP_HOST=localhost RUBY_YJIT_ENABLE=0 RUBY_ZJIT_ENABLE=0
case $n in
  codetriage|pingcrm) export DATABASE_ADAPTER=postgresql ;;
  fizzy-mysql) export DATABASE_ADAPTER=mysql MYSQL_USER=root MYSQL_HOST=127.0.0.1 MYSQL_PORT=3307 ;;
  *) export DATABASE_ADAPTER=sqlite ;;
esac
unset RUBYOPT
cd $dir
r() { mise exec ruby@4.0.7 -- "$@"; }
census() { r bundle exec ruby $root/bench/upstream/rails_main_census_4.rb prepare $n; }
case $n in
  blog|campfire|writebook|fizzy|fizzy-mysql|codetriage)
    [ $n = codetriage ] && { [ -f config/database.yml ] || cp config/database.example.yml config/database.yml; }
    mkdir -p log tmp storage
    r bundle exec rails db:create db:schema:load
    [ $n = fizzy-mysql ] || r bundle exec rails assets:precompile
    census ;;
  pingcrm)
    bun install --frozen-lockfile
    r bundle exec rails db:create db:schema:load
    r bundle exec rails runner 'require "faker"; Faker::Config.random = Random.new(42); load "db/seeds.rb"'
    r bundle exec rails assets:precompile ;;
  redprints-cfp|react-starter-kit)
    if [ $n = redprints-cfp ]; then bun install --frozen-lockfile; else npm ci --no-audit --no-fund; fi
    mkdir -p log tmp storage
    r bundle exec rails db:prepare
    r bundle exec rails assets:precompile ;;
  lobsters)
    cp config/database.yml.sample config/database.yml
    mkdir -p log tmp storage
    r bundle exec rails db:prepare
    r bundle exec rails runner /tmp/w/lob-fake.rb
    r bundle exec rails assets:precompile ;;
esac
echo PREPARED $n
