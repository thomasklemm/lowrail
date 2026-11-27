#!/bin/bash
# `bundle install` of a repository's committed Gemfile.lock at a given commit: ./autoswitch_repo.sh RUBY_PREFIX OWNER/REPO SHA
# Fresh GEM_HOME, BUNDLE_PATH and HOME per run, so the locked Bundler is never preinstalled. RUBY_UPGRADE=1 first
# sets .ruby-version to the running Ruby and drops the Gemfile's `ruby` line, as an app moving to that Ruby would.
set -u
ruby=$1; repo=$2; sha=$3
dir=$(mktemp -d /tmp/aswr.XXXX)
git init -q "$dir/src" && git -C "$dir/src" fetch -q --depth 1 "https://github.com/$repo" "$sha" && git -C "$dir/src" checkout -q FETCH_HEAD
export PATH=$ruby/bin:/usr/bin:/bin GEM_HOME=$dir/gems GEM_PATH=$dir/gems BUNDLE_PATH=$dir/vendor HOME=$dir/home BUNDLE_JOBS=4
mkdir -p "$HOME"; cd "$dir/src"
if [ -n "${RUBY_UPGRADE:-}" ]; then
  [ -f .ruby-version ] && ruby -e 'print RUBY_VERSION' > .ruby-version
  sed -i -E '/^ruby[ (]/d' Gemfile
fi
bw=$(sed -n '/BUNDLED WITH/{n;p}' Gemfile.lock | tr -d ' ')
out=$(timeout 900 bundle install 2>&1); st=$?
sw=$(echo "$out" | grep -m1 -oE 'Installing Bundler [0-9.]+' || true)
res=$(echo "$out" | grep -m1 -oE 'NameError: .{0,60}|Bundle complete!' || echo "$out" | tail -1 | cut -c1-120)
echo "ruby=$(ruby -e 'print RUBY_VERSION, " ", RUBY_REVISION[0,10]') repo=$repo sha=${sha:0:10} bundled_with=$bw exit=$st switch='$sw' result='$res'"
echo "$out" > "/tmp/aswr-$(echo "$repo" | tr / _)-$(ruby -e 'print RUBY_REVISION[0,10]').log"
rm -rf "$dir"
