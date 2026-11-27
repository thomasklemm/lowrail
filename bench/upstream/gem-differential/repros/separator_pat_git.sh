#!/bin/bash
# Same as repro.sh with a git source: lock generated on 4.0.10, BUNDLED WITH set to $2, `bundle install` on Ruby $1.
set -u
# Repro for SEP1 (docs/upstream/ruby41-gem-differential.md): ./FILE RUBY_PREFIX BUNDLED_WITH_VERSION
ruby=$1; bundled=$2
dir=$(mktemp -d /tmp/seppatg.XXXX); mkdir -p $dir/foo/lib $dir/app
cd $dir/foo && echo 'module Foo; end' > lib/foo.rb
printf 'Gem::Specification.new { |s| s.name = "foo"; s.version = "0.1.0"; s.summary = "f"; s.authors = ["x"]; s.files = ["lib/foo.rb"] }\n' > foo.gemspec
git init -q && git add . && git -c user.name=x -c user.email=x@x commit -qm i
cd $dir/app && printf 'source "https://rubygems.org"\ngem "foo", git: "file://%s/foo"\n' $dir > Gemfile
export BUNDLE_PATH=$dir/vendor GEM_HOME=$dir/gems GEM_PATH=$dir/gems
PATH=$HOME/rdiff/rubies/v4.0.10/bin:/usr/bin:/bin bundle lock > /tmp/seppat-lock.log 2>&1 || { cat /tmp/seppat-lock.log; exit 2; }
sed -i "/BUNDLED WITH/{n;s/.*/   $bundled/}" Gemfile.lock
out=$(PATH=$ruby/bin:/usr/bin:/bin bundle install 2>&1); st=$?
echo "git source: ruby=$(PATH=$ruby/bin ruby -e 'print RUBY_VERSION') bundled_with=$bundled exit=$st $(echo "$out" | grep -m1 -oE 'NameError: .{0,60}|Bundle complete!')"
