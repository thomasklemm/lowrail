#!/bin/bash
# Minimal repro: a gem developed with `gemspec` in its Gemfile, lockfile BUNDLED WITH $2, `bundle install` on Ruby $1.
set -u
# Repro for SEP1 (docs/upstream/ruby41-gem-differential.md): ./FILE RUBY_PREFIX BUNDLED_WITH_VERSION
ruby=$1; bundled=$2
dir=$(mktemp -d /tmp/seppat.XXXX); cd "$dir"
mkdir -p lib exe
echo 'module Foo; end' > lib/foo.rb
printf '#!/usr/bin/env ruby\n' > exe/foo
cat > foo.gemspec <<'G'
Gem::Specification.new do |s|
  s.name = "foo"; s.version = "0.1.0"; s.summary = "foo"; s.authors = ["x"]
  s.files = ["lib/foo.rb", "exe/foo"]; s.bindir = "exe"; s.executables = ["foo"]
end
G
printf 'source "https://rubygems.org"\ngemspec\n' > Gemfile
cat > Gemfile.lock <<L
PATH
  remote: .
  specs:
    foo (0.1.0)

GEM
  remote: https://rubygems.org/
  specs:

PLATFORMS
  ruby
  x86_64-linux

DEPENDENCIES
  foo!

BUNDLED WITH
   $bundled
L
export PATH=$ruby/bin:/usr/bin:/bin BUNDLE_PATH=$dir/vendor GEM_HOME=$dir/gems GEM_PATH=$dir/gems
out=$(bundle install 2>&1); st=$?
echo "ruby=$(ruby -e 'print RUBY_VERSION') bundled_with=$bundled exit=$st $(echo "$out" | grep -m1 -oE 'NameError: [^\n]*|Bundle complete!')"
