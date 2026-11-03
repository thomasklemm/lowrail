#!/usr/bin/env bash
# Census runs for docs/upstream/combined-effect.md, in ABBA order so that state
# accumulating across runs (write workloads) does not favour either tree:
# with (main), without (PRs reverted), without2, with2.
#   bench/upstream/combined_effect/census_abba.sh RAILS_REPO MAIN_SHA REVERTED_SHA APPS [JOBS]
set -euo pipefail
repo=$1 main=$2 reverted=$3 apps=$4 jobs=${5:-4}
cd "$(dirname "$0")/../../.."
run() { script/census run --label "$1" --rails "$repo@$2" --apps "$apps" --modes interp,yjit --jobs "$jobs"; }
run with "$main"
run without "$reverted"
run without2 "$reverted"
run with2 "$main"
