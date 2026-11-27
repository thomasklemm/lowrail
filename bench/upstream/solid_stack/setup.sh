#!/usr/bin/env bash
# The measured app: `rails new` from Rails main with the Rails 8 default stack, Solid Queue, Cache and Cable each in
# their own database (SQLite, or PostgreSQL with DB=pg), plus app_overlay (Gemfiles that load the four gems from
# ~/w/rel = released tags, ~/w/main = their main branches, ~/w/cand = candidate branches; the PG database.yml;
# a Fizzy-like Card model, job and partials). Four copies, stackapp-1..4, for parallel A/A runs.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
export PATH="$(~/.local/bin/mise where ruby@4.0.10)/bin:$PATH"
cd ~/w
[ -d rails-main ] || git clone -q --filter=blob:none https://github.com/rails/rails.git rails-main
for g in solid_queue:v1.7.2:rails solid_cache:v1.0.10:rails solid_cable:v4.1.0:rails turbo-rails:v2.0.23:hotwired; do
  IFS=: read -r name tag org <<< "$g"
  [ -d "$name" ] || git clone -q "https://github.com/$org/$name.git"
  [ -d "rel/$name" ] || git -C "$name" worktree add -q "../rel/$name" "$tag"
  [ -d "main/$name" ] || git -C "$name" worktree add -q --detach "../main/$name" origin/main
done
(cd rails-main && bundle install -q)
BUNDLE_GEMFILE=~/w/rails-main/Gemfile bundle exec ruby rails-main/railties/exe/rails new stackapp --dev --skip-kamal \
  --skip-thruster --skip-docker --skip-ci --skip-brakeman --skip-rubocop --skip-bundler-audit --skip-system-test \
  --skip-git --skip-bundle
cp -r "$here/app_overlay/." stackapp/
cd stackapp
bundle install -q && BUNDLE_GEMFILE=Gemfile.main bundle install -q
for t in solid_cache:install solid_queue:install solid_cable:install; do bin/rails "$t"; done
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails db:prepare
cd ..
for i in 1 2 3 4; do
  rm -rf "stackapp-$i" && cp -r stackapp "stackapp-$i"
  (cd "stackapp-$i" && DB=pg DBSUFFIX=_$i RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails db:prepare)
done
