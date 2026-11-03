#!/usr/bin/env bash
# Census runs for docs/upstream/i18n-performance.md on the gem census copies (Rails 5810776eec):
# the A/A pair ib/ib2 on i18n master, then one label per candidate. Deltas:
#   ruby bench/upstream/gem_census/gem_delta.rb .lowrail/private/census i18n ib ib2 c1 interpreter
set -euo pipefail
cd "$(dirname "$0")/../../.."
apps=sure,docuseal,discourse,casa,loomio,mastodon,lobsters,blog,codetriage,pingcrm
run() { script/census run --modes interp,yjit --jobs "${JOBS:-4}" --apps "$apps" "$@"; }
run --label ib --aa --gem i18n=ruby-i18n/i18n@a0a416e570fd4998993bde1b5533d0a038bebaf7
for spec in c1:38dc6cff841b81be46d6b4ccf29a25c7fc3b0824 c2:3bef11d6e3d174a1666fa5c73ed57b6159c08e25 \
            c3:b82af9eeae49d8fd0d018c3494fca37fa5229bc7 c4:dd3d1e05f6f32fa29555881cd93c579e0bdab203; do
  run --label "${spec%%:*}" --gem "i18n=thomasklemm/i18n@${spec#*:}"
done
# Reworked C1 and C4 after review.
run --label c1b --gem i18n=thomasklemm/i18n@0ff39e7cbfccdf4b4cdaa65aabdfaa6527836ae6
run --label c4b --gem i18n=thomasklemm/i18n@0b552378da4401908539c28ddffdd832a6d22944
