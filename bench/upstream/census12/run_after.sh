#!/usr/bin/env bash
# After run_census.sh: census 11's main under YJIT, then the diagnostics, one at a time.
set -u
cd /home/user/workspace/repo
export PATH=$HOME/.local/bin:$PATH
. bench/upstream/census12/heap.sh
# (run_census.sh had finished when this started)
APPS=blog,writebook,codetriage,pingcrm,redprints-cfp,react-starter-kit,casa,hackatime
C11=rails/rails@cf0325a832a1594f01d866da1e4ad23d962d886b
step() { echo "== $* $(date -u +%T)"; "$@"; echo "exit $? $(date -u +%T)"; }
B=docs/upstream/data/rails-main-census-12/bisect
mkdir -p $B
# The one new workload slowdown since census 11, over its 67 first-parent commits.
step mise exec ruby@4.0.9 -- ruby bench/upstream/census12/bisect.rb redprints-cfp "deliver ProposalMailer#proposal_submitted" \
  cf0325a832a1594f01d866da1e4ad23d962d886b 088fc0cf61e4ba0c7987decafacc69adb3e22eec
# The one workload slower than 8.1: #56213's merge against its first parent.
step mise exec ruby@4.0.9 -- ruby bench/upstream/census12/bisect.rb codetriage "perform SendSingleTriageEmailJob" \
  38a74b851c^ 38a74b851c
step bash bench/upstream/census12/stacks.sh
step mise exec ruby@4.0.9 -- script/cpu-census run --label c12c11 --rails $C11 --apps $APPS --modes yjit --jobs ${JOBS:-4}
cp .lowrail/private/cpu-bisect/*.tsv $B/; cp .lowrail/private/cpu-bisect-only/redprints-cfp.tsv $B/redprints-cfp-only.tsv
echo AFTERDONE
sleep infinity
