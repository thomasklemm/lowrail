#!/usr/bin/env bash
# Hackatime one-process captures with the checkout's lowrail-profile: g1..g6 unchanged, then gp1, gp2 with the field test's plant.
set -u
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.7/bin:$PATH
export TEST_DATABASE_URL=postgres://user@localhost/ft_hackatime_test PARALLEL_WORKERS=1
cd /home/user/workspace/repo/.corpus/ft-hackatime
mkdir -p ~/hk
cap() { t0=$(date +%s); RAILS_ENV=test bin/rails db:schema:load > /dev/null 2>&1; BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile --keep-runs --out ~/hk/$1 -- bin/rails test -v > ~/hk/$1.log 2>&1; echo "$1 exit $? $(( $(date +%s) - t0 ))s at $(date -u +%T)" >> ~/hk/summary.txt; }
for n in g1 g2 g3 g4 g5 g6; do cap $n; done
sed -i '4a\    20.times { ERB::Util.html_escape("a<b") }' app/controllers/leaderboards_controller.rb
true
for n in gp1 gp2; do cap $n; done
git checkout -q -- app/controllers/leaderboards_controller.rb
exec sleep infinity
