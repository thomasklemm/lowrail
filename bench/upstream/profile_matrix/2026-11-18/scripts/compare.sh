#!/usr/bin/env bash
# compare.sh APPDIR OUTDIR: compare profiled (base) with head, --aa base2, in Markdown and JSON.
app=$1; D=$2
v=$(sed 's/ruby-//' "$app/.ruby-version"); export PATH="$(~/.local/bin/mise where ruby@$v)/bin:$PATH"
cd "$app"
BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile compare $D/profiled/report.json $D/head/report.json --aa $D/base2/report.json > $D/compare.md; echo "markdown exit $?" | tee $D/compare.exit
BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile compare $D/profiled/report.json $D/head/report.json --aa $D/base2/report.json --json > $D/compare.json; echo "json exit $?" | tee -a $D/compare.exit
BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile compare $D/profiled/report.json $D/head/report.json > $D/compare-noaa.md; echo "no --aa exit $?" | tee -a $D/compare.exit
