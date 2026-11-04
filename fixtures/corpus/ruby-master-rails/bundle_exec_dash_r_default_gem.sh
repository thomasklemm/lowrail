#!/usr/bin/env bash
# Ruby master: `bundle exec ruby -rjson` activates the default json instead of
# the locked one, also with no other json installed (empty GEM_HOME/GEM_PATH).
# Same cause as ../ruby-41-readiness/repro/bundle_exec_dash_r.sh; this variant
# needs no globally installed gem, because json is a default gem.
#   usage: bundle_exec_dash_r_default_gem.sh RUBY_BIN_DIR
set -eu
export PATH=$1:$PATH
dir=$(mktemp -d); cd "$dir"
printf 'source "https://rubygems.org"\ngem "json", "3.0.1"\n' > Gemfile
BUNDLE_PATH=$dir/b bundle install --quiet
sed -i '/BUNDLED WITH/,$d' Gemfile.lock
GEM_HOME=$dir/empty GEM_PATH=$dir/empty BUNDLE_PATH=$dir/b bundle exec ruby -rjson -e 'puts JSON::VERSION'
# 4.0.9 (default json 2.18.0): 3.0.1
# master 5888302d4f (default json 3.1.0): Gem::LoadError: You have already activated json 3.1.0,
#   but your Gemfile requires json 3.0.1.
