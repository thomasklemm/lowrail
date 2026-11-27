#!/bin/bash
set -u
# Control for SEP1: a lockfile with only rubygems.org gems (no PATH or GIT): ./FILE RUBY_PREFIX BUNDLED_WITH_VERSION
ruby=$1; bundled=$2
dir=$(mktemp -d /tmp/seppatr.XXXX); cd "$dir"
printf 'source "https://rubygems.org"\ngem "rake"\n' > Gemfile
export BUNDLE_PATH=$dir/vendor GEM_HOME=$dir/gems GEM_PATH=$dir/gems
PATH=$HOME/rdiff/rubies/v4.0.10/bin:/usr/bin:/bin bundle lock > /tmp/seppatr-lock.log 2>&1 || { cat /tmp/seppatr-lock.log; exit 2; }
sed -i "/BUNDLED WITH/{n;s/.*/   $bundled/}" Gemfile.lock
out=$(PATH=$ruby/bin:/usr/bin:/bin bundle install 2>&1); st=$?
echo "rubygems only: ruby=$(PATH=$ruby/bin ruby -e 'print RUBY_VERSION') bundled_with=$bundled exit=$st $(echo "$out" | grep -m1 -oE 'NameError: .{0,60}|Bundle complete!|Installing Bundler [0-9.]+')"
