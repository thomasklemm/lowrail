#!/usr/bin/env bash
# usage: earlier.sh — rechecks the two Ruby-side findings of 2026-11-04 on r409 and master with the round-1 repros
# (fixtures/corpus/ruby-41-readiness/repro), each in a scratch dir under $R3/earlier; prints both outputs.
here=$(cd "$(dirname "$0")" && pwd)
repro=$here/../ruby-41-readiness/repro
for l in r409 master; do (
  source "$here/env.sh" "$l"
  unset BUNDLE_FROZEN RAILS_ENV
  echo "== $l: $(ruby -v)"
  echo "-- bundle exec ruby -rGEM (rainbow 2.2.2 locked, 3.1.1 installed)"
  GEM_HOME=$R3/globalgems/$l BUNDLE_PATH= bash "$repro/bundle_exec_dash_r.sh" "$RUBY_BIN" 2>&1 | grep -v '^\s*from '
  echo "-- default net-http with net-protocol 0.2.2 locked"
  d=$R3/earlier/netproto-$l; rm -rf "$d"; mkdir -p "$d"; cp "$repro"/net-protocol-022/* "$d/"; cd "$d"
  BUNDLE_PATH=$d/b bundle install --quiet 2>&1
  BUNDLE_PATH=$d/b bundle exec ruby repro.rb 2>&1 | grep -v '^\s*from '
); done
