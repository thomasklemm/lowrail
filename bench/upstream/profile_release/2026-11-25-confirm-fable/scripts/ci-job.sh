#!/usr/bin/env bash
# ci-job.sh RUBY README : the README's CI job on a clone of the T1 app, for an unchanged head, a head with a planted
# regression, a head whose suite fails, a base whose suite fails, and with PARALLEL_WORKERS: 2.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); . "$here/../env.sh" "$1"; readme=$2; T=/tmp/pr2
repo=/tmp/pr/a81/ci; rm -rf "$repo"; git clone -q /tmp/pr/a81/t1 "$repo"; cd "$repo"
g() { git -c user.name=x -c user.email=x@x "$@"; }
base=$(git rev-parse HEAD)
g commit -q --allow-empty -m unchanged; same=$(git rev-parse HEAD)
ruby -pi -e 'sub(/^    @articles = Article.all\n/, %(    @articles = Article.all\n    20.times { ERB::Util.html_escape("a<b") }\n))' app/controllers/articles_controller.rb
g commit -qam planted; planted=$(git rev-parse HEAD)
git checkout -q "$base"; printf 'require "test_helper"\nclass FailingTest < ActiveSupport::TestCase\n  test("fails") { assert false }\nend\n' > test/models/failing_test.rb
git add -A; g commit -qm failing; failing=$(git rev-parse HEAD); git checkout -q "$base"
show() {
  grep -E "^## (Regressions|Improvements)|Insufficient|compare exited|A report, not a gate|^\* |ran in" "$1" | cut -c1-230 | head -8
  grep -E "^\| (line|action)" "$1" | cut -c1-200 | head -6
}
for case in same planted failing; do
  rm -rf tmp/base tmp/base2 tmp/head
  echo "== head: $case"
  ruby "$here/ci-job.rb" "$readme" "$repo" "$base" "${!case}" "$T/ci-$case.md"; show "$T/ci-$case.md"
  git checkout -q "$base" 2>/dev/null
done
echo "== base: failing, head: unchanged"
rm -rf tmp/base tmp/base2 tmp/head
ruby "$here/ci-job.rb" "$readme" "$repo" "$failing" "$same" "$T/ci-basefail.md"; show "$T/ci-basefail.md"; cat "$T/ci-basefail.md.Compare.log" | head -5
git checkout -q "$base" 2>/dev/null
echo "== head: planted, the job with PARALLEL_WORKERS: 2"
sed 's/^    PARALLEL_WORKERS: 1.*$/    PARALLEL_WORKERS: 2/' "$readme" > $T/README-par.md
rm -rf tmp/base tmp/base2 tmp/head
ruby "$here/ci-job.rb" $T/README-par.md "$repo" "$base" "$planted" $T/ci-par.md; show $T/ci-par.md
