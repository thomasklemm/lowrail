#!/bin/bash
# wbrun.sh ROUND MODE... : writebook, one pool variant at a time, fresh DB before each run.
round=$1; shift
export CENSUS_GC_OPS=1000
base=/home/user/workspace/repo/.lowrail/private/ruby-41-watch
app=/home/user/workspace/repo/.corpus/census4-writebook
reset() {
  cd $app && rm -f storage/db/production.sqlite3* tmp/census4-fixtures.json
  env BUNDLE_FROZEN=true RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 SKIP_TELEMETRY=1 APP_VERSION=census DATABASE_ADAPTER=sqlite RAILS_LOG_LEVEL=fatal \
    mise exec ruby@gcstep -- bundle exec rails db:create db:schema:load > /tmp/w/logs/wb-reset.log 2>&1 &&
  env BUNDLE_FROZEN=true RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 SKIP_TELEMETRY=1 APP_VERSION=census DATABASE_ADAPTER=sqlite RAILS_LOG_LEVEL=fatal \
    mise exec ruby@gcstep -- bundle exec ruby /home/user/workspace/repo/bench/upstream/rails_main_census_4.rb prepare writebook >> /tmp/w/logs/wb-reset.log 2>&1
}
for mode in "$@"; do
  for v in ${VARIANTS:-bytes slots 2xbytes minpages2 slotscap8}; do
    reset || { echo "reset failed"; exit 1; }
    out=$base/gs-$v-$round; mkdir -p $out /tmp/w/gsteps/$v-$round
    rm -f $out/writebook-$mode.json /tmp/w/gsteps/$v-$round/writebook-$mode-*
    GCSTEP_LOG=/tmp/w/gsteps/$v-$round/writebook-$mode RUBY_GC_POOL_MODE=$v \
      /tmp/w/c4.sh gcstep writebook $mode profile $out/writebook-$mode.json > /tmp/w/logs/gs-$v-$round-writebook-$mode.log 2>&1
    echo "$(date +%T) $round $mode writebook $v rc=$?"
  done
done
