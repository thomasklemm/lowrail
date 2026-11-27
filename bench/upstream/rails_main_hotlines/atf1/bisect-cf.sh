#!/usr/bin/env bash
# bisect-cf.sh REF: campfire's ContentFiltersTest with Rails at REF (path gem from the bisect worktree).
ref=$1
git -C /home/user/r82/bisect checkout --quiet --detach "$ref" || exit 125
cd /home/user/workspace/repo/.corpus/hl-campfire
export PATH="$(~/.local/bin/mise where ruby@4.0.7)/bin:$PATH" RAILS_ENV=test REDIS_URL=redis://localhost:6379/1
sed 's|^gem "rails", github: .*|gem "rails", path: "/home/user/r82/bisect"|' Gemfile > Gemfile.bisect
ruby -e 'l = File.read("Gemfile.lock"); l.sub!(/^GIT\n  remote: https:\/\/github.com\/rails\/rails.git\n  revision: \h+\n(?:  ref: \h+\n|  branch: \S+\n)?/, "PATH\n  remote: /home/user/r82/bisect\n"); File.write("Gemfile.bisect.lock", l)'
export BUNDLE_GEMFILE=$PWD/Gemfile.bisect
bundle install --quiet > /tmp/bisect-cf-install.log 2>&1 || { echo "$ref bundle-fail"; exit 125; }
bin/rails test test/helpers/content_filters_test.rb > /tmp/bisect-cf.log 2>&1
echo "$ref $(grep -E '^[0-9]+ runs' /tmp/bisect-cf.log | tail -1)"
grep -qE '^[0-9]+ runs' /tmp/bisect-cf.log || exit 125
grep -qE ' 0 failures, 0 errors' /tmp/bisect-cf.log
