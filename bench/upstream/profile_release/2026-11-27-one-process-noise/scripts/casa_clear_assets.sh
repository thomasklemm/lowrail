#!/usr/bin/env bash
# CASA spec/requests with the final lowrail-profile (~/gemwork): z1..z4 clear Sprockets' tmp/cache/assets before every
# run (inside the profiled command), each capture after db:test:prepare; zp1 the same with the field test's plant.
set -u
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.7/bin:$PATH POSTGRES_USER=user DATABASE_HOST=localhost
cd /home/user/workspace/repo/.corpus/ft-casa
cap() {
  t0=$(date +%s)
  RAILS_ENV=test bin/rails db:test:prepare > ~/casa/$1.prepare.log 2>&1
  BUNDLE_GEMFILE=Gemfile.final bundle exec lowrail-profile --keep-runs --out ~/casa/$1 -- sh -c 'rm -rf tmp/cache/assets && exec bundle exec rspec spec/requests --seed 1234 --format documentation' > ~/casa/$1.log 2>&1
  echo "$1 exit $? $(( $(date +%s) - t0 ))s at $(date -u +%T)" >> ~/casa/summary.txt
}
for n in z1 z2 z3 z4; do cap $n; done
sed -i '10a\    20.times { ERB::Util.html_escape("a<b") }' app/controllers/casa_cases_controller.rb
cap zp1
git checkout -q -- app/controllers/casa_cases_controller.rb
exec sleep infinity
