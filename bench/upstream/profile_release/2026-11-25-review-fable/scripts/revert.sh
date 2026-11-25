#!/usr/bin/env bash
# revert.sh RUBY COMMIT NAME_REGEX : COMMIT's tests against COMMIT^'s gem code (lib, exe, ext, README, docs),
# in the worktree /tmp/pr/wt. A new test must fail there and pass at COMMIT.
set -uo pipefail
ruby=$1 c=$2 names=$3
export PATH="$(mise where ruby@$ruby)/bin:$PATH"
cd /tmp/pr/wt
git checkout -q --detach "$c" && git reset -q --hard "$c"
run() {
  (cd gem && ruby -Ilib -Itest -e 'ARGV.select { _1.end_with?(".rb") }.each { require File.expand_path("test/#{_1}") }; ARGV.reject! { _1.end_with?(".rb") }' -- \
    profile_test.rb profile_compare_test.rb --seed=1729 -n "/$names/" 2>&1)
}
at=$(run | grep -E '^[0-9]+ runs,' | tail -1)
git checkout -q "$c^" -- gem/lib gem/exe gem/ext gem/README-profile.md docs/profile.md
log=/tmp/pr/revert-$c-$ruby.log
run > "$log"
echo "$c ruby $ruby | at commit: $at | code of $c^: $(grep -E '^[0-9]+ runs,' "$log" | tail -1)"
grep -E '^(ProfileTest|ProfileCompareTest)#|^  [0-9]+\) (Failure|Error)' "$log" | sed 's/^/    /' | head -12
git reset -q --hard "$c"
