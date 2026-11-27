#!/usr/bin/env bash
# casa-sprockets.sh: judges_spec profiled 4 times keeping tmp/cache/assets, then 4 times clearing it before each capture.
set -u
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.7/bin:$PATH POSTGRES_USER=user DATABASE_HOST=localhost
cd /home/user/workspace/repo/.corpus/ft-casa
cap() { BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile --keep-runs --out ~/casa/$1 -- bundle exec rspec spec/requests/judges_spec.rb --seed 1234 > ~/casa/$1.log 2>&1
  echo "$1 $? $(jq -c '[.actions[]|select(.name=="JudgesController#edit")|.warm]' ~/casa/$1/report.json)" >> ~/casa/sprockets.txt; }
for n in k1 k2 k3 k4; do cap $n; done
for n in x1 x2 x3 x4; do rm -rf tmp/cache/assets; cap $n; done
