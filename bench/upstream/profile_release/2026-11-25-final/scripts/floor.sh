#!/usr/bin/env bash
# floor.sh GEM: the floor Blog (Ruby 3.3.14, Rails 7.2.4) proof from the final gem, as part 1 of
# ../../2026-11-25-fixes/scripts/rerun.sh: proof.sh, controls.sh, compare.sh, outcomes, margin and load order.
set -u
here=$(cd "$(dirname "$0")" && pwd); out=$(cd "$here/.." && pwd); repo=$(cd "$here/../../../../.." && pwd)
s=$repo/bench/upstream/profile_release/2026-11-25/scripts gem=$1 floor=$repo/.corpus/rc-blog-floor o=$out/blog-floor
add='20.times { ERB::Util.html_escape("a<b") }'
rm -f "$floor"/Gemfile.lowrail*; rm -rf "$o"
PLANT="app/controllers/articles_controller.rb:5a\\    $add" "$s/proof.sh" "$floor" "$o" "$gem" \
  plain,plain2,off,profiled,base2,head,planted,seed99 -- bin/rails test -v
"$s/controls.sh" "$floor" "$o" -- bin/rails test -v
"$s/compare.sh" "$floor" "$o"
cd "$floor" && export PATH="$(~/.local/bin/mise where ruby@3.3.14)/bin:$PATH"
BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile compare "$o/profiled/report.json" "$o/seed99/report.json" \
  --aa "$o/base2/report.json" > "$o/compare-seed99.md"; echo "seed99 --aa exit $?" >> "$o/compare.exit"
ruby "$s/outcomes.rb" "$o"/{plain,plain2,off,off-env,profiled,base2,head,planted,seed99}.log > "$o/outcomes.txt"
for f in "$o"/*.outcomes; do cmp -s "$o/plain.outcomes" "$f" && echo "$(basename "$f") = plain" || echo "$(basename "$f") DIFFERS"; done >> "$o/outcomes.txt"
ruby -I"$repo/gem/lib" "$s/margin.rb" "$o/profiled/report.json" "$o/head/report.json" "$o/base2/report.json" > "$o/margin.txt"
{ echo "# plain vs plain2, off"; ruby "$s/features_cmp.rb" "$o" plain plain2,off
  echo "# control (bundle exec env) vs captures"; ruby "$s/features_cmp.rb" "$o" off-env profiled,base2,head,planted,seed99; } > "$o/features.txt"
