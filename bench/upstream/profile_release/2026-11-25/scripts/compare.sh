#!/usr/bin/env bash
# compare.sh APPDIR OUTDIR: base (profiled) against head and planted, --aa base2; and without --aa.
app=$1; D=$(cd "$2" && pwd)
v=$(sed 's/ruby-//' "$app/.ruby-version"); export PATH="$(~/.local/bin/mise where ruby@$v)/bin:$PATH"
cd "$app"; unset RUBYLIB RUBYOPT
c() { BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile compare "$@"; }
for h in head planted; do
  [ -d "$D/$h" ] || continue
  c $D/profiled/report.json $D/$h/report.json --aa $D/base2/report.json > $D/compare-$h.md; echo "$h --aa exit $?" | tee -a $D/compare.exit
  c $D/profiled/report.json $D/$h/report.json --aa $D/base2/report.json --json > $D/compare-$h.json
done
c $D/profiled/report.json $D/head/report.json > $D/compare-noaa.md; echo "head without --aa exit $?" | tee -a $D/compare.exit
