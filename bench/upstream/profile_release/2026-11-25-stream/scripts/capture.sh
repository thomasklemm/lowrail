#!/usr/bin/env bash
# capture.sh APP OUT [Gemfile]: one --keep-runs capture with the installed gem
set -u
app=$1 out=$2 gf=${3:-Gemfile.lowrail}
export PATH="$(~/.local/bin/mise where ruby@4.0.7)/bin:$PATH"; unset RUBYLIB RUBYOPT
export XDG_CACHE_HOME=/tmp/stream-cache
cd "$app" && rm -rf "$out" && BUNDLE_GEMFILE=$gf SEED=1234 bundle exec lowrail-profile --keep-runs --out "$out" -- bin/rails test -v > "$out.log" 2>&1
echo "$app exit $?"
