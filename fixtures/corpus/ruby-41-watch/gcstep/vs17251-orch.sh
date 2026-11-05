#!/bin/bash
# orch.sh MODE... : census GC windows, 4 builds x rounds a,b
root=/home/user/workspace/repo
wbreset() {
  cd $root/.corpus/census4-writebook && rm -f storage/db/production.sqlite3* tmp/census4-fixtures.json
  env BUNDLE_FROZEN=true RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 SKIP_TELEMETRY=1 APP_VERSION=census DATABASE_ADAPTER=sqlite RAILS_LOG_LEVEL=fatal \
    mise exec ruby@gsm -- bundle exec rails db:create db:schema:load > /tmp/w/logs/wb-reset.log 2>&1 &&
  env BUNDLE_FROZEN=true RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 SKIP_TELEMETRY=1 APP_VERSION=census DATABASE_ADAPTER=sqlite RAILS_LOG_LEVEL=fatal \
    mise exec ruby@gsm -- bundle exec ruby $root/bench/upstream/rails_main_census_4.rb prepare writebook >> /tmp/w/logs/wb-reset.log 2>&1
}
for mode in "$@"; do
  for a in ${PAR_APPS-blog campfire fizzy redprints-cfp lobsters}; do
    for r in a b; do for l in master pr pool both; do $(dirname $0)/vs17251-cell.sh $l $r $a $mode & done; done
    wait; echo "$(date +%T) $mode $a"
  done
  for a in ${SEQ_APPS-writebook react-starter-kit fizzy-mysql codetriage pingcrm}; do
    for rl in "a master" "a pr" "a pool" "a both" "b both" "b pool" "b pr" "b master"; do
      set -- $rl
      [ $a = writebook ] && { wbreset || echo "wb reset failed" >> /tmp/w/logs/missing; }
      $(dirname $0)/vs17251-cell.sh $2 $1 $a $mode
    done
    echo "$(date +%T) $mode $a"
  done
done
echo ORCH-DONE
