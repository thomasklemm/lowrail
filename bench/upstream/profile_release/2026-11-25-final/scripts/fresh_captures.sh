#!/usr/bin/env bash
# fresh_captures.sh APPDIR GEMHOME OUTDIR NAME...: one plain run (once), then an unchanged capture per NAME, each
# from emptied tables, as thermos-fable ran them. (No plant here: /widgets is requested once per worker
# process, so a plant there has no warm value; plants are checked on the four corpus apps.)
set -u
app=$1 gh=$2 out=$3; shift 3
export GEM_HOME=$gh GEM_PATH=$gh PATH="$gh/bin:$(~/.local/bin/mise where ruby@4.0.7)/bin:$PATH"
unset RUBYOPT RUBYLIB BUNDLE_GEMFILE
mkdir -p "$out"; out=$(cd "$out" && pwd); export XDG_CACHE_HOME=$out/cache
cd "$app"
reset() { RAILS_ENV=test bin/rails runner 'Widget.delete_all; Tally.delete_all' > /dev/null 2>&1; }
if [ ! -f "$out/plain.log" ]; then reset; SEED=1234 bin/rails test -v > "$out/plain.log" 2>&1; echo "plain exit $?" >> "$out/summary.txt"; fi
for n in "$@"; do
  reset; rm -rf "$out/$n"
  bundle exec lowrail-profile --out "$out/$n" -- bin/rails test -v > "$out/$n.log" 2>&1; echo "$n exit $?" >> "$out/summary.txt"
done
