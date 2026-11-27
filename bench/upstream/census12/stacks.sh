#!/usr/bin/env bash
# Sampled stacks on main for the workloads where census 12's hot methods peak,
# one cpu-census run per workload (CENSUS_CPU_STACKS keeps one window), then
# callers.rb for each method. Diagnostic labels s12-*, not census labels.
set -u
cd /home/user/workspace/repo
export PATH=$HOME/.local/bin:$PATH
. bench/upstream/census12/heap.sh
MAIN=rails/rails@088fc0cf61e4ba0c7987decafacc69adb3e22eec
OUT=.lowrail/private/cpu-stacks
mkdir -p $OUT docs/upstream/data/rails-main-census-12/callers
while IFS='|' read -r app workload patterns; do
  [ -z "$app" ] && continue
  slug=$(echo "$app-$workload" | tr -c 'A-Za-z0-9\n' '-' | tr -s '-')
  stacks=$PWD/$OUT/$slug.json
  if [ ! -e "$stacks" ]; then
    CENSUS_CPU_STACKS=$stacks mise exec ruby@4.0.9 -- script/cpu-census run --out $OUT --label "s12-$slug" --rails $MAIN \
      --apps "$app" --modes interp --jobs 1 --only "$workload"
  fi
  for pat in $patterns; do
    mise exec ruby@4.0.9 -- ruby bench/upstream/census12/callers.rb "$stacks" "$pat" 2
  done > docs/upstream/data/rails-main-census-12/callers/$slug.txt
done <<'EOF'
blog|PATCH article.json|IsolatedExecutionState\.\[\] InheritableOptions#initialize ParameterFilter#value_for_key String#blank\? Fanout#(groups_for|build_handle)|FanoutIteration Hash#symbolize_keys! connection_specification_name compute_if_absent
blog|GET article|String#blank\? IsolatedExecutionState\.\[\] InheritableOptions#initialize csrf_token_hmac|xor_byte_strings
blog|GET article.json|Engine#build_request IsolatedExecutionState\.\[\]
writebook|GET books|InheritableOptions#initialize TagBuilder#tag_options IsolatedExecutionState\.\[\]
hackatime|PATCH display name (Inertia redirect)|ParameterFilter#value_for_key Hash#stringify_keys IsolatedExecutionState\.\[\]
react-starter-kit|GET dashboard (Inertia JSON)|Hash#extract! IsolatedExecutionState\.\[\]
casa|GET casa case edit|compute_if_absent IsolatedExecutionState\.\[\] String#blank\?
hackatime|perform DashboardRollupRefreshJob|Time#change Hash#stringify_keys cache_quoted_name
pingcrm|POST contact invalid (Inertia errors)|Inflector#apply_inflections Hash#extract!
hackatime|GET leaderboards|Object#deep_dup|Array#deep_dup|Hash#deep_dup
EOF
echo STACKSDONE
