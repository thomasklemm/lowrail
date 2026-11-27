#!/usr/bin/env bash
# apav-bundle.sh LANE RUBYDIR : install Rails main's lockfile for one Ruby
lane=$1 ruby=$2
cd ~/rdiff/apav/rails-$lane
export PATH=$ruby/bin:$PATH BUNDLE_PATH=$HOME/rdiff/apav/bundle-$lane BUNDLE_FROZEN=true BUNDLE_WITHOUT="rubocop:mdl:doc:job:cable:storage:db" BUNDLE_JOBS=2
gem list -i bundler -v 4.0.12 >/dev/null || gem install -N bundler -v 4.0.12
bundle install > ~/rdiff/apav/bundle-$lane.log 2>&1; echo "bundle $lane status=$?"
