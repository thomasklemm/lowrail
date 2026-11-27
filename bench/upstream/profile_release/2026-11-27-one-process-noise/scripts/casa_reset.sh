#!/usr/bin/env bash
# CASA spec/requests captures with the changed lowrail-profile, each after bin/rails db:test:prepare (the README's
# CI job): r1..r6 unchanged, rp1 with the field test's plant in CasaCasesController#index.
set -u
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.7/bin:$PATH POSTGRES_USER=user DATABASE_HOST=localhost
cd /home/user/workspace/repo/.corpus/ft-casa
cap() {
  t0=$(date +%s)
  RAILS_ENV=test bin/rails db:test:prepare > ~/casa/$1.prepare.log 2>&1
  psql -h localhost -U user casa_test -tAc "select last_value from pg_sequences where sequencename='users_id_seq'" >> ~/casa/$1.prepare.log
  BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile --keep-runs --out ~/casa/$1 -- bundle exec rspec spec/requests --seed 1234 --format documentation > ~/casa/$1.log 2>&1
  echo "$1 exit $? $(( $(date +%s) - t0 ))s at $(date -u +%T)" >> ~/casa/summary.txt
}
for n in r1 r2 r3 r4 r5 r6; do cap $n; done
sed -i '10a\    20.times { ERB::Util.html_escape("a<b") }' app/controllers/casa_cases_controller.rb
for n in rp1; do cap $n; done
git checkout -q -- app/controllers/casa_cases_controller.rb
exec sleep infinity
