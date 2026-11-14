#!/usr/bin/env bash
# AB1 review runs: main, the branch and main again (A/A), interleaved, five rounds, one pinned core.
#   ab1_review.sh RUBY_BIN GEMFILE_DIR_MAIN GEMFILE_DIR_FIX "RUBY FLAGS" SCRIPT [ARGS...]
# GEMFILE_DIR_* hold a Gemfile with actionpack from rails main 50c54eed06 or the branch (207a7827a7).
set -uo pipefail
bin=$1 main=$2 fix=$3 flags=$4 script=$5; shift 5
here=$(cd "$(dirname "$0")" && pwd)
for round in 1 2 3 4 5; do
  for label in base candidate base2; do
    dir=$main; [ "$label" = candidate ] && dir=$fix
    echo "=== $label $flags round $round"
    "$bin/ruby" $flags -e "puts RUBY_DESCRIPTION"
    BUNDLE_GEMFILE=$dir/Gemfile PATH="$bin:$PATH" taskset -c 1 "$bin/ruby" $flags -rbundler/setup -I "$here" "$script" "$@" 2>&1 |
      grep -v -e '^Warming' -e '^Calculating' -e 'i/100ms$'
  done
done
