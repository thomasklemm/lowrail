#!/usr/bin/env bash
# rerun.sh GEM: the receipts the M5 fixes touch, from the rebuilt gem, with ../../2026-11-25/scripts.
# 1. The floor Blog (Ruby 3.3.14, Rails 7.2.4) as on 2026-11-25: proof.sh, controls.sh, compare.sh.
# 2. On the floor Blog and a Ruby 4.0.7 / Rails 8.1.4 Blog: exit status of a real failing and a killed suite,
#    plain and profiled (KILL: Rails' runner turns TERM into exit 1); and the --workloads write guard (writes counted in the development database).
set -u
here=$(cd "$(dirname "$0")" && pwd); out=$(cd "$here/.." && pwd); repo=$(cd "$here/../../../../.." && pwd)
s=$repo/bench/upstream/profile_release/2026-11-25/scripts
gem=$1
floor=$repo/.corpus/rc-blog-floor blog81=$repo/.corpus/rc-blog-81
add='20.times { ERB::Util.html_escape("a<b") }'
rm -f "$floor"/Gemfile.lowrail* "$blog81"/Gemfile.lowrail*
rm -rf "$out/blog-floor" "$out"/*-probes

PLANT="app/controllers/articles_controller.rb:5a\\    $add" "$s/proof.sh" "$floor" "$out/blog-floor" "$gem" \
  plain,plain2,off,profiled,base2,head,planted,seed99 -- bin/rails test -v
"$s/controls.sh" "$floor" "$out/blog-floor" -- bin/rails test -v
"$s/compare.sh" "$floor" "$out/blog-floor"
(cd "$floor" && export PATH="$(~/.local/bin/mise where ruby@3.3.14)/bin:$PATH" &&
  BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile compare "$out/blog-floor/profiled/report.json" \
    "$out/blog-floor/seed99/report.json" --aa "$out/blog-floor/base2/report.json" > "$out/blog-floor/compare-seed99.md"
  echo "seed99 --aa exit $?" >> "$out/blog-floor/compare.exit"
  ruby "$s/outcomes.rb" "$out"/blog-floor/{plain,plain2,off,off-env,profiled,base2,head,planted,seed99}.log > "$out/blog-floor/outcomes.txt"
  for f in "$out"/blog-floor/*.outcomes; do cmp -s "$out/blog-floor/plain.outcomes" "$f" && echo "$(basename "$f") = plain" || echo "$(basename "$f") DIFFERS"; done >> "$out/blog-floor/outcomes.txt"
  ruby -I"$repo/gem/lib" "$s/margin.rb" "$out/blog-floor/profiled/report.json" "$out/blog-floor/head/report.json" \
    "$out/blog-floor/base2/report.json" > "$out/blog-floor/margin.txt"
  { echo "# plain vs plain2, off"; ruby "$s/features_cmp.rb" "$out/blog-floor" plain plain2,off
    echo "# control (bundle exec env) vs captures"; ruby "$s/features_cmp.rb" "$out/blog-floor" off-env profiled,base2,head,planted,seed99; } \
    > "$out/blog-floor/features.txt")

# 2. Exit status and the write guard, per Blog.
for app in "$floor" "$blog81"; do
  name=$(basename "$app"); d=$out/$name-probes; rm -rf "$d"; mkdir -p "$d"
  [ -f "$app/Gemfile.lowrail" ] || "$s/proof.sh" "$app" "$d/install" "$gem" "" -- true
  v=$(sed 's/ruby-//' "$app/.ruby-version")
  (cd "$app" && export PATH="$(~/.local/bin/mise where ruby@$v)/bin:$PATH" BUNDLE_GEMFILE=Gemfile.lowrail XDG_CACHE_HOME="$d/cache" && unset RUBYLIB RUBYOPT
   r=$d/results.txt; : > "$r"
   ruby -v >> "$r"; bundle exec ruby -e 'puts "rails #{Gem.loaded_specs["rails"].version}, lowrail-profile from #{Gem.loaded_specs["lowrail-profile"].full_gem_path}"' >> "$r"
   t=test/models/article_test.rb
   for kind in failing killed; do
     if [ $kind = failing ]; then body='assert_equal 1, 2'; else body='Process.kill("KILL", Process.pid)'; fi
     sed -i "\$i\\  test \"planted $kind\" do\\n    $body\\n  end" $t
     git diff > "$d/$kind.patch"
     SEED=1234 bin/rails test -v > "$d/$kind-plain.log" 2>&1; echo "$kind suite, plain: exit $?" >> "$r"
     bundle exec lowrail-profile --out "$d/$kind" -- bin/rails test -v > "$d/$kind-profiled.log" 2>&1
     echo "$kind suite, profiled: exit $? (runs: $(sed -n 3p "$d/$kind/command.txt"))" >> "$r"
     git checkout -q -- $t
   done
   bin/rails db:prepare > "$d/db.log" 2>&1
   count() { bin/rails runner 'puts Article.count' 2>/dev/null; }
   mkdir -p "$d/w"
   probe='get "/articles", name: "probe", env: { "REQUEST_METHOD" => "POST" }, params: { article: { title: "probe", body: "A probe that is long enough." } }, expect: [200, 302, 422]'
   write='post articles_path, params: { article: { title: "probe", body: "A probe that is long enough." } }, expect: [302]'
   for c in "probe|$probe|" "probe|$probe|--allow-writes" "post|$write|--allow-writes"; do
     label=${c%%|*}; rest=${c#*|}; line=${rest%|*}; flag=${rest##*|}
     printf 'get "/articles"\n%s\n' "$line" > "$d/w/$label.rb"
     before=$(count)
     bundle exec lowrail-profile --out "$d/w/$label${flag:+-allow}" --workloads "$d/w/$label.rb" $flag > "$d/w/$label${flag:+-allow}.log" 2>&1
     st=$?; after=$(count)
     echo "workloads $label ${flag:-(no flag)}: exit $st, articles $before -> $after; $(grep -m1 -E 'is sent as|needs --allow-writes|exited' "$d/w/$label${flag:+-allow}.log")" >> "$r"
   done)
done
# Kept as on 2026-11-25: per capture capture.json, command.txt, report.md, report.json.gz; per step the outcomes
# and the log's last 40 lines. Raw runs, feature dumps, counter builds and full logs are removed.
for d in "$out/blog-floor" "$out"/*-probes; do
  for c in "$d"/*/ "$d"/w/*/; do [ -f "$c/report.json" ] && gzip -f "$c/report.json"; rm -rf "$c"/run[0-9]* "$c"/workloads.json "$c"/.lowrail-profile; done
  rm -rf "$d"/*.features "$d"/cache "$d"/install/cache
  for l in "$d"/*.log "$d"/w/*.log; do [ -f "$l" ] && { tail -40 "$l" > "${l%.log}.tail.txt"; rm "$l"; }; done
done
du -sh "$out"
echo ALL DONE
