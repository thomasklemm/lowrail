#!/usr/bin/env bash
# PHR1 on Dawarich: lowrail-profile captures base, aa (base again) and head of posthog-rails 3.18.6, which differ only
# in tracing_headers.rb (../phr is a symlink to either copy; the lock stays the same).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/dw-env.sh"
export RSWAG_GENERATING=1
cd ~/oss/dawarich
for cap in base aa head; do
  side=$([ "$cap" = head ] && echo head || echo base)
  ln -sfn phr-src/$side/posthog-rails-3.18.6 ~/oss/phr
  rm -rf tmp/lp-$cap
  mise exec ruby@4.0.9 -- bundle exec lowrail-profile --out tmp/lp-$cap -- bundle exec rspec $(cat "$here/dw-specs.txt") --format documentation > /tmp/dw-$cap.txt 2>&1
  echo "$cap exit $?" >> /tmp/dw-profile.status
done
ln -sfn phr-src/base/posthog-rails-3.18.6 ~/oss/phr
mise exec ruby@4.0.9 -- bundle exec lowrail-profile compare tmp/lp-base/report.json tmp/lp-head/report.json --aa tmp/lp-aa/report.json > /tmp/dw-compare.txt 2>&1
echo "compare exit $?" >> /tmp/dw-profile.status
