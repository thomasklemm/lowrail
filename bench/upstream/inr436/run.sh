#!/bin/bash
# Differential probe for INR436. Usage: run.sh OUTDIR BUNDLED_CHECKOUT RUBY RAILS TREE...
# BUNDLED_CHECKOUT is any inertia-rails checkout with `bundle install` done into vendor/bundle for RAILS;
# each TREE is an inertia-rails worktree whose lib/ is probed. Compare two outputs with compare.py A.jsonl B.jsonl.
set -e
out=$1 bundled=$2 ruby=$3 rails=$4; shift 4; mkdir -p "$out"
here=$(cd "$(dirname "$0")" && pwd)
for tree in "$@"; do
  name=$(basename "$tree")
  BUNDLE_GEMFILE=$bundled/Gemfile BUNDLE_PATH=$bundled/vendor/bundle RAILS_VERSION=$rails mise exec ruby@"$ruby" -- \
    bundle exec ruby "$here/probe.rb" "$tree" > "$out/$name.jsonl" 2> "$out/$name.err"
  echo "$name ($(/usr/bin/git -C "$tree" rev-parse --short HEAD)): $(wc -l < "$out/$name.jsonl") rows"
done
