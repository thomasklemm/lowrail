#!/usr/bin/env bash
# usage: all.sh — round 3 as it ran on 2026-11-16: fetch each app, prepare its bundle, build its assets, run it on
# r409, master and zjit. Needs Ruby 4.0.9 and the master build named in env.sh, libvips, node and bun, and a local
# PostgreSQL that the current user can create databases on. Logs: $R3/runs/LABEL/APP.log.
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
cd "$root"
P=$here/prep.sh C=$here/chain.sh
rspec_bump="rspec-rails rspec-core rspec-expectations rspec-mocks rspec-support"
for a in campfire-r82 writebook-r82 fizzy-r82 thinkroom react-starter-kit redprints-cfp pingcrm codetriage hackatime; do
  script/corpus "$a" "r3-${a%-r82}" --source-only
done
# env.sh resets PATH, so keep node and bun from the calling shell.
tools="$(dirname "$(command -v node)"):$(dirname "$(command -v bun)")"
assets() { local a=$1; shift; (cd ".corpus/r3-$a" && source "$here/env.sh" r409 && export PATH="$PATH:$tools" && "$@"); }

$P .corpus/r3-campfire campfire-r82
EXTRA_UPDATES=redcarpet $P .corpus/r3-writebook writebook-r82
$P .corpus/r3-fizzy fizzy-r82
(cd .corpus/r3-fizzy && git apply "$here/../ruby-master-round-2/fizzy-rails-main-uuid.patch")
EXTRA_UPDATES=commonmarker $P .corpus/r3-thinkroom inertia-chatwoot-census/thinkroom
EXTRA_UPDATES="$rspec_bump" $P .corpus/r3-react-starter-kit rails-main-census-5/react-starter-kit
GEMFILE_EDITS='s/^gem "sqlite3", ">= 2.1"$/gem "sqlite3", ">= 2.1", force_ruby_platform: true/' \
  GEMFILE_APPEND=$'gem "ffi", force_ruby_platform: true\ngem "herb", force_ruby_platform: true\ngem "nokogiri", force_ruby_platform: true' \
  EXTRA_UPDATES="$rspec_bump" $P .corpus/r3-redprints-cfp rails-main-census-5/redprints-cfp
$P .corpus/r3-pingcrm rails-main-census-5/pingcrm
GEMFILE_EDITS='/^gem "bluecloth"$/d' EXTRA_UPDATES=rbtrace $P .corpus/r3-codetriage rails-main-census-5/codetriage
$P .corpus/r3-hackatime inertia-chatwoot-census/hackatime

(cd .corpus/r3-thinkroom && npm ci --no-audit --no-fund) && assets thinkroom env RAILS_ENV=test bundle exec vite build
(cd .corpus/r3-react-starter-kit && npm ci --no-audit --no-fund && RAILS_ENV=test npx vite build)
for a in redprints-cfp pingcrm; do (cd ".corpus/r3-$a" && bun install --frozen-lockfile) && assets "$a" env RAILS_ENV=test bundle exec vite build; done

$C campfire writebook fizzy thinkroom
RUNNER=rspec $C react-starter-kit redprints-cfp
PG=1 $C pingcrm
PG=1 TEST_ARGS="test/dependency_parsers test/emails test/functional test/helpers test/integration test/jobs test/mailers test/unit" $C codetriage
PG=1 PARALLEL_WORKERS=1 $C hackatime
for a in campfire writebook fizzy thinkroom react-starter-kit redprints-cfp pingcrm codetriage hackatime; do
  SHOW_BASE=1 ruby "$here/compare.rb" "$a"
done
