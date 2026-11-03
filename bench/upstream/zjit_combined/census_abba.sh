#!/usr/bin/env bash
# Census runs for the ZJIT section of docs/upstream/combined-effect.md on the
# Ruby master pin: allocations (interp, zjit) in ABBA order, then ZJIT stats
# (fallback and exit counters) per tree twice, in separate processes.
#   bench/upstream/zjit_combined/census_abba.sh RUBY_BIN WITH_SPEC WITHOUT_SPEC APPS [JOBS]
set -euo pipefail
ruby=$1 with=$2 without=$3 apps=$4 jobs=${5:-4}
cd "$(dirname "$0")/../../.."
export CENSUS_WARMUP=${CENSUS_WARMUP:-200}
c=(--corpus censusf2 --ruby "$ruby" --apps "$apps" --jobs "$jobs")
run() { script/census run --label "$1" --rails "$2" --modes interp,zjit "${c[@]}"; }
stats() { script/census run --label "$1" --rails "$2" --modes zjit --stats="--zjit-mem-size=${ZJIT_MEM:-128}" "${c[@]}"; }
run zw "$with"; run zwo "$without"; run zwo2 "$without"; run zw2 "$with"
stats zsw "$with"; stats zswo "$without"; stats zswo2 "$without"; stats zsw2 "$with"
