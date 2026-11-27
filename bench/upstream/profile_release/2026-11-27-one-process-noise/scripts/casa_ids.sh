#!/usr/bin/env bash
# casa-ids.sh NAME START: CASA's checklist_items request spec profiled after every sequence is set to START.
set -u
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.7/bin:$PATH POSTGRES_USER=user DATABASE_HOST=localhost
cd /home/user/workspace/repo/.corpus/ft-casa
psql -h localhost -U user casa_test -qtAc "select setval(c.oid::regclass, $2, false) from pg_class c where c.relkind='S'" > /dev/null
BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile --keep-runs --out ~/casa/$1 -- bundle exec rspec spec/requests/checklist_items_spec.rb --seed 1234 > ~/casa/$1.log 2>&1
echo "$1 exit $?"
