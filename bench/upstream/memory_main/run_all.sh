#!/usr/bin/env bash
# The round recorded in README.md: plain A/A runs (ABBA over the Rails trees), then one detail run per
# configuration.   bench/upstream/memory_main/run_all.sh OUT
set -euo pipefail
out=$1
cd "$(dirname "$0")/../../.."
args=(--ruby r4010="$HOME/rubies/4.0.10-zjit" --ruby master="$HOME/rubies/master-0d399335b7"
  --rails r81=3f290b759c8e2ffe7c257951b1255740751355e4 --rails main=2e299253f942ab94041cc6f210ac9d33884c210d
  --apps "${APPS:-blog,writebook,pingcrm,redprints-cfp,react-starter-kit,sure}" --modes interp,zjit)
mise=$HOME/.local/bin/mise
[[ -n ${SKIP_PLAIN:-} ]] || "$mise" exec ruby@4.0.10 -- ruby bench/upstream/memory_main/run.rb --out "$out" "${args[@]}" --reps 2 --jobs 4
"$mise" exec ruby@4.0.10 -- ruby bench/upstream/memory_main/run.rb --out "$out" "${args[@]}" --detail --jobs 3
echo "ALL DONE $(date -u +%T)"
