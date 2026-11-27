#!/bin/bash
# Bundler autoswitch on Ruby 4.1: `bundle install` for a PATH (gemspec) or GIT lockfile with BUNDLED WITH $3.
# ./autoswitch_matrix.sh RUBY_PREFIX gemspec|git BUNDLED_WITH [VARIANT]
# VARIANT: plain (default) | env-system (BUNDLE_VERSION=system) | config-system (`bundle config set version system`)
#          | env-bundler (BUNDLER_VERSION=<running>) | update (`bundle update --bundler`, then install)
#          | update-explicit (`bundle _<running>_ update --bundler`, then install) | frozen (BUNDLE_FROZEN=true)
#          | after-fail-VARIANT (a plain `bundle install` first, which installs the old Bundler, then VARIANT)
# Each run uses its own GEM_HOME, so the old Bundler is never preinstalled. NOPATH=1 leaves BUNDLE_PATH unset, so
# gems (and the old Bundler) go to GEM_HOME, as in a default setup.
set -u
ruby=$1; kind=$2; bundled=$3; variant=${4:-plain}
dir=$(mktemp -d /tmp/asw.XXXX)
export PATH=$ruby/bin:/usr/bin:/bin GEM_HOME=$dir/gems GEM_PATH=$dir/gems HOME=$dir/home
[ -n "${NOPATH:-}" ] || export BUNDLE_PATH=$dir/vendor
mkdir -p "$HOME" "$dir/foo/lib" "$dir/app"
echo 'module Foo; end' > "$dir/foo/lib/foo.rb"
printf 'Gem::Specification.new do |s|\n  s.name = "foo"; s.version = "0.1.0"; s.summary = "foo"; s.authors = ["x"]; s.files = ["lib/foo.rb"]\nend\n' > "$dir/foo/foo.gemspec"
if [ "$kind" = gemspec ]; then
  app=$dir/foo; remote="PATH
  remote: ."; printf 'source "https://rubygems.org"\ngemspec\n' > "$app/Gemfile"; dep='foo!'
else
  (cd "$dir/foo" && git init -q && git add . && git -c user.name=x -c user.email=x@x commit -qm i)
  rev=$(git -C "$dir/foo" rev-parse HEAD)
  app=$dir/app; remote="GIT
  remote: file://$dir/foo
  revision: $rev"; printf 'source "https://rubygems.org"\ngem "foo", git: "file://%s/foo"\n' "$dir" > "$app/Gemfile"; dep='foo!'
fi
cat > "$app/Gemfile.lock" <<L
$remote
  specs:
    foo (0.1.0)

GEM
  remote: https://rubygems.org/
  specs:

PLATFORMS
  ruby
  x86_64-linux

DEPENDENCIES
  $dep

BUNDLED WITH
   $bundled
L
cd "$app"
running=$(bundle -v | grep -oE '[0-9][0-9.a-z]*$')
pre=""; first=""
case $variant in after-fail-*) first=$(bundle install 2>&1 | grep -m1 -oE 'NameError|Bundle complete!'); variant=${variant#after-fail-} ;; esac
case $variant in
  plain) out=$(bundle install 2>&1); st=$? ;;
  env-system) out=$(BUNDLE_VERSION=system bundle install 2>&1); st=$? ;;
  config-system) bundle config set --local version system >/dev/null 2>&1; out=$(bundle install 2>&1); st=$? ;;
  env-bundler) out=$(BUNDLER_VERSION=$running bundle install 2>&1); st=$? ;;
  frozen) out=$(BUNDLE_FROZEN=true bundle install 2>&1); st=$? ;;
  update) pre=$(bundle update --bundler 2>&1); pst=$?; out=$(bundle install 2>&1); st=$? ;;
  update-explicit) pre=$(bundle "_${running}_" update --bundler 2>&1); pst=$?; out=$(bundle install 2>&1); st=$? ;;
esac
after=$(sed -n '/BUNDLED WITH/{n;p}' Gemfile.lock | tr -d ' ')
sw=$(echo "$pre$out" | grep -m1 -oE 'Installing Bundler [0-9.]+' || true)
err=$(echo "$pre$out" | grep -m1 -oE 'NameError: .{0,60}|Bundle complete!' || true)
echo "ruby=$(ruby -e 'print RUBY_REVISION[0,10]') bundler=$running kind=$kind bundled_with=$bundled variant=${first:+after-fail($first)-}$variant ${pre:+update_exit=$pst }exit=$st switch='${sw}' result='${err}' lock_after=$after"
[ -n "${VERBOSE:-}" ] && { echo "$pre"; echo "$out"; }
rm -rf "$dir"
