#!/usr/bin/env bash
# usage: prep.sh APP_DIR CORPUS — reset APP_DIR (a script/corpus copy) to its pin plus fixtures/corpus/CORPUS.patch,
# move its Rails git pin to $RAILS_MAIN, drop `ruby file: ".ruby-version"` (three Rubies share one lockfile), lock with
# Ruby 4.0.9, and install the bundle for each Ruby in $LABELS. Only the Rails git revision and what Rails main forces
# change in the lockfile, plus the knobs: GEMFILE_EDITS (sed), GEMFILE_APPEND (lines), EXTRA_UPDATES (gem names).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
app=$(cd "$1" && pwd)
overlay=$(cd "$here/.." && pwd)/${2:?corpus name, e.g. campfire-r82}.patch
RAILS_MAIN=${RAILS_MAIN:-78039119db862ad739d41677a840f3657fb34d93}
cd "$app"
git checkout -q -- .
[ -f "$overlay" ] && git apply "$overlay"
# A .bundle/config holding only "---" crashes Bundler 4.0.20 on master (known, frontier-master README).
[ "$(cat .bundle/config 2>/dev/null)" = "---" ] && rm .bundle/config
sed -i '' -E "s|^gem \"rails\", github: \"rails/rails\".*|gem \"rails\", github: \"rails/rails\", ref: \"$RAILS_MAIN\"|" Gemfile
sed -i '' -E '/^ruby file: ".ruby-version"/d' Gemfile
# Per-app Gemfile edits for known 4.1 gem breaks, e.g. GEMFILE_EDITS='s/"~> 2.6.3"/"= 2.10.1"/'
[ -n "${GEMFILE_EDITS:-}" ] && sed -i '' -E "$GEMFILE_EDITS" Gemfile
# Apps with a platform-only gem (bundlebun) cannot add the ruby platform; force the source build per gem instead,
# as fixtures/corpus/frontier-master does, e.g. GEMFILE_APPEND='gem "herb", force_ruby_platform: true'
[ -n "${GEMFILE_APPEND:-}" ] && printf '%s\n' "$GEMFILE_APPEND" >> Gemfile
grep -q "ref: \"$RAILS_MAIN\"" Gemfile
ruby_lock_rewrite='
  lock = File.read("Gemfile.lock")
  lock.sub!(%r{(remote: https://github.com/rails/rails.git\n  revision: )\h+\n  (?:(?:branch|ref): \S+\n)?}) { "#{$1}#{ENV["RAILS_MAIN"]}\n  ref: #{ENV["RAILS_MAIN"]}\n" } or abort "no rails git block"
  File.write("Gemfile.lock", lock)'
(
  source "$here/env.sh" r409
  RAILS_MAIN=$RAILS_MAIN ruby -e "$ruby_lock_rewrite"
  BUNDLE_FROZEN=false bundle lock
  # Rails main 78039119db requires rails-html-sanitizer >= 1.7.2; plain `bundle lock` keeps the git specs' old deps.
  BUNDLE_FROZEN=false bundle lock --conservative --update rails-html-sanitizer
  # Known 4.1 gem breaks (gems-on-master.md), bumped on every Ruby so the bundles stay identical.
  [ -n "${EXTRA_UPDATES:-}" ] && BUNDLE_FROZEN=false bundle lock --conservative --update $EXTRA_UPDATES
  # Precompiled nokogiri/sqlite3/herb builds stop at Ruby 4.0, so master needs the source gems.
  [ -n "${GEMFILE_APPEND:-}" ] || BUNDLE_FROZEN=false bundle lock --add-platform ruby
)
for label in ${LABELS:-r409 master}; do
  (source "$here/env.sh" "$label" && bundle install --quiet && echo "$label bundle ok")
done
git diff --stat
