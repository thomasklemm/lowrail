#!/usr/bin/env bash
# Ruby master: `bundle exec ruby -rGEM` loads GEM before bundler/setup, so it
# activates whatever version is installed globally instead of the locked one.
# Ruby 4.0 set Bundler up while RubyGems loaded (Feature #19089); since
# c3c0e280d0 / cadf8e79a6 (Feature #21951) gem_prelude.rb skips that whenever
# error_highlight & co. are autoloaded, and RUBYOPT's -rbundler/setup runs after
# command-line -r. ruby/ruby#18400 changed the spec for this instead.
#   usage: bundle_exec_dash_r.sh RUBY_BIN_DIR   (needs rainbow 3.x installed globally)
set -eu
export PATH=$1:$PATH
gem list -i rainbow -v '>= 3' >/dev/null || gem install rainbow -v 3.1.1 --no-document >/dev/null
dir=$(mktemp -d); cd "$dir"
printf 'source "https://rubygems.org"\ngem "rainbow", "2.2.2"\n' > Gemfile
BUNDLE_PATH=$dir/b bundle install --quiet
BUNDLE_PATH=$dir/b bundle exec ruby -rrainbow -e 'puts Gem.loaded_specs["rainbow"].version'
# 4.0.9: 2.2.2
# master: Gem::LoadError: You have already activated rainbow 3.1.1, but your Gemfile requires rainbow 2.2.2.
