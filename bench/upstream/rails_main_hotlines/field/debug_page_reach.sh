#!/usr/bin/env bash
# debug_page_reach.sh APP...: each census app's hot-lines suite on Rails main (its Gemfile.main-a when adapted, else
# Gemfile.main), unprofiled, with debug_page_count.rb preloaded. Output: reach/APP.txt (counts, suite tail).
here=$(cd "$(dirname "$0")" && pwd); hl=$here/../../profile_hotlines_census
mkdir -p "$here/reach"
for app in "$@"; do
  DIR=/home/user/workspace/repo/.corpus/hl-$app; tree=main; [ -f "$DIR/Gemfile.main-a.done" ] && tree=main-a
  PREP() { :; }; source "$hl/apps/$app.sh"
  out=$here/reach/$app.txt; : > "$out"; : > "$out.log"
  (
    export PATH="$(~/.local/bin/mise where ruby@$RUBY)/bin:$HOME/.local/bin:$PATH"
    unset RUBYLIB BUNDLE_GEMFILE
    export SEED=1234 DISABLE_SPRING=1 PARALLEL_WORKERS=1 XDG_CACHE_HOME=/home/user/rmh-out/$app/cache
    cd "$DIR"; export BUNDLE_GEMFILE=$DIR/Gemfile.$tree; PREP
    export DEBUG_PAGE_COUNT_OUT=$out RUBYOPT="-r$here/debug_page_count.rb"
    t0=$(date +%s.%N); "${CMD[@]}" > "$out.log" 2>&1
    echo "app=$app tree=$tree exit=$? wall=$(echo "$(date +%s.%N) - $t0" | bc)" >> "$out"
  )
  grep -E "runs,|examples," "$out.log" | tail -1 >> "$out"
done
echo REACHDONE
