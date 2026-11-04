#!/bin/bash
# eco.sh DIR LABEL CMD...   bundle and run CMD in gem checkout DIR against Rails LABEL (81 | main).
# Rails checkouts: ~/src/eco/rails-81 (8-1-stable) and ~/src/eco/rails-main. The main lock starts from the
# 8-1 lock, so gems other than Rails keep their versions where they can (eco-locks.rb diffs them).
# ECO_ROOT and ECO_RUBY override the checkout root and the Ruby (the readiness runner sets both).
set -e
dir=$1 label=$2; shift 2
here=$(cd "$(dirname "$0")" && pwd)
gf="$dir/$(dirname "${ECO_GEMFILE:-Gemfile}")/Gemfile.eco-$label"
cp "$here/Gemfile.eco" "$gf"
# eval_gemfile path is relative to the wrapper's dir; keep wrapper next to the target Gemfile
export ECO_GEMFILE=$(basename "${ECO_GEMFILE:-Gemfile}")
export ECO_RAILS=${ECO_ROOT:-$HOME/src/eco}/rails-$label BUNDLE_GEMFILE=$gf
[ "$label" = main ] && [ -f "$(dirname "$gf")/Gemfile.eco-81.lock" ] && [ ! -f "$gf.lock" ] && cp "$(dirname "$gf")/Gemfile.eco-81.lock" "$gf.lock"
cd "$dir"
mise exec ruby@${ECO_RUBY:-4.0.9} -- bundle install --quiet --jobs 4 >&2
exec mise exec ruby@${ECO_RUBY:-4.0.9} -- bundle exec "$@"
