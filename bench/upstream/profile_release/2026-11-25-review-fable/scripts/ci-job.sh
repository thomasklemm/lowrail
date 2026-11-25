#!/usr/bin/env bash
# ci-job.sh RUBY : the README's CI job on a clone of the T1 app, for an unchanged head, a head with a planted
# regression, a head whose suite fails, and without PARALLEL_WORKERS (two workers).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh" "$1"
readme=/tmp/pr/unpacked/lowrail-profile-0.1.0.rc1/README-profile.md
repo=/tmp/pr/a81/ci; rm -rf "$repo"; git clone -q /tmp/pr/a81/t1 "$repo"; cd "$repo"
g() { git -c user.name=x -c user.email=x@x "$@"; }
base=$(git rev-parse HEAD)
g commit -q --allow-empty -m unchanged; same=$(git rev-parse HEAD)
ruby -pi -e 'sub(/^    @articles = Article.all\n/, %(    @articles = Article.all\n    20.times { ERB::Util.html_escape("a<b") }\n))' app/controllers/articles_controller.rb
g commit -qam planted; planted=$(git rev-parse HEAD)
git checkout -q "$base"; printf 'require "test_helper"\nclass FailingTest < ActiveSupport::TestCase\n  test("fails") { assert false }\nend\n' > test/models/failing_test.rb
git add -A; g commit -qm failing; failing=$(git rev-parse HEAD); git checkout -q "$base"
for case in same planted failing; do
  rm -rf tmp/base tmp/base2 tmp/head
  echo "== head: $case"
  ruby "$here/ci-job.rb" "$readme" "$repo" "$base" "${!case}" "/tmp/pr/ci-$case.md"
  grep -E "^## (Regressions|Improvements)|Insufficient|compare exited|A report, not a gate" "/tmp/pr/ci-$case.md" | cut -c1-160
  grep -E "^\| (line|action)" "/tmp/pr/ci-$case.md" | cut -c1-200 | head -6
  git checkout -q "$base" 2>/dev/null
done
echo "== head: planted, the job without PARALLEL_WORKERS: 1 (two workers)"
sed 's/^    PARALLEL_WORKERS: 1.*$/    PARALLEL_WORKERS: 2/' "$readme" > /tmp/pr/README-par.md
rm -rf tmp/base tmp/base2 tmp/head
ruby "$here/ci-job.rb" /tmp/pr/README-par.md "$repo" "$base" "$planted" /tmp/pr/ci-par.md
grep -E "^## (Regressions|Improvements)|Insufficient|compare exited|ran in" /tmp/pr/ci-par.md | cut -c1-260
