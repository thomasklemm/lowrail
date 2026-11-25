#!/usr/bin/env bash
# blog81.sh GEM: rerun.sh's floor-Blog proof (part 1) on the Ruby 4.0.7 / Rails 8.1.4 Blog (.corpus/rc-blog-81),
# plus three more unchanged captures (aa3..aa5) for the A/A question. Run after rerun.sh.
set -u
here=$(cd "$(dirname "$0")" && pwd); out=$(cd "$here/.." && pwd); repo=$(cd "$here/../../../../.." && pwd)
s=$repo/bench/upstream/profile_release/2026-11-25/scripts
gem=$1 app=$repo/.corpus/rc-blog-81 d=$out/blog-81
add='20.times { ERB::Util.html_escape("a<b") }'
rm -rf "$d"
PLANT="app/controllers/articles_controller.rb:5a\\    $add" "$s/proof.sh" "$app" "$d" "$gem" \
  plain,plain2,off,profiled,base2,head,planted,seed99,aa3,aa4,aa5 -- bin/rails test -v
"$s/controls.sh" "$app" "$d" -- bin/rails test -v
"$s/compare.sh" "$app" "$d"
(cd "$app" && export PATH="$(~/.local/bin/mise where ruby@4.0.7)/bin:$PATH" &&
  BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile compare "$d/profiled/report.json" \
    "$d/seed99/report.json" --aa "$d/base2/report.json" > "$d/compare-seed99.md"
  echo "seed99 --aa exit $?" >> "$d/compare.exit"
  ruby "$s/outcomes.rb" "$d"/{plain,plain2,off,off-env,profiled,base2,head,planted,seed99,aa3,aa4,aa5}.log > "$d/outcomes.txt"
  for f in "$d"/*.outcomes; do cmp -s "$d/plain.outcomes" "$f" && echo "$(basename "$f") = plain" || echo "$(basename "$f") DIFFERS"; done >> "$d/outcomes.txt"
  ruby -I"$repo/gem/lib" "$s/margin.rb" "$d/profiled/report.json" "$d/head/report.json" "$d/base2/report.json" > "$d/margin.txt"
  { echo "# plain vs plain2, off"; ruby "$s/features_cmp.rb" "$d" plain plain2,off
    echo "# control (bundle exec env) vs captures"; ruby "$s/features_cmp.rb" "$d" off-env profiled,base2,head,planted,seed99,aa3,aa4,aa5; } \
    > "$d/features.txt")
for c in "$d"/*/; do [ -f "$c/report.json" ] && gzip -f "$c/report.json"; rm -rf "$c"/run[0-9]* "$c"/.lowrail-profile; done
rm -rf "$d"/*.features "$d"/cache
for l in "$d"/*.log; do [ -f "$l" ] && { tail -40 "$l" > "${l%.log}.tail.txt"; rm "$l"; }; done
echo ALL DONE
