#!/usr/bin/env bash
# HM1 on CodeTriage: the suite plain, then lowrail-profile captures of base, aa (base again) and head of hashie 5.1.0,
# which differ only in mash.rb (hashie-5.1.0-head.diff; ~/oss/hm is a symlink to either copy, the lock stays the same).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
app=$(cd "$here/../../../../.corpus/rc-codetriage" && pwd)
out=${OUT:-/tmp/hm1-ct}
mkdir -p "$out"
export PATH="$(mise where ruby@4.0.7)/bin:$PATH" SEED=1234
unset RUBYLIB RUBYOPT
cd "$app"
ln -sfn hm-src/base/hashie-5.1.0 ~/oss/hm
bin/rails test --verbose > "$out/plain.log" 2>&1; echo "plain exit $?" >> "$out/status"
for cap in base aa head; do
  side=$([ "$cap" = head ] && echo head || echo base)
  ln -sfn hm-src/$side/hashie-5.1.0 ~/oss/hm
  rm -rf "$out/$cap"
  bundle exec lowrail-profile --out "$out/$cap" -- bin/rails test --verbose > "$out/$cap.log" 2>&1
  echo "$cap exit $?" >> "$out/status"
done
ln -sfn hm-src/base/hashie-5.1.0 ~/oss/hm
bundle exec lowrail-profile compare "$out/base/report.json" "$out/head/report.json" --aa "$out/aa/report.json" > "$out/compare.txt" 2>&1
echo "compare exit $?" >> "$out/status"
