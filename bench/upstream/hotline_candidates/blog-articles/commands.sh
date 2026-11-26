#!/usr/bin/env bash
# How runs 1-3 were made (2026-11-26, 2-CPU orb). Paths are the orb's; adjust W and the repo root.
set -euo pipefail
W=/home/user/work
git clone -q --filter=blob:none https://github.com/ruby-concurrency/concurrent-ruby.git $W/concurrent-ruby
for t in cr138 cr138-fwd cr138-ref cr138-aaa; do git -C $W/concurrent-ruby worktree add -q ../$t v1.3.8; done
git -C $W/cr138-fwd apply "$PWD/bench/upstream/hotline_candidates/blog-articles/concurrent-ruby-1.3.8-fwd.diff"
BENCH_TOOL_JOBS=2 bash script/bench-valgrind $W/valgrind-brk512
cargo build
LOWRAIL_CORPUS_RUBY=4.0.7 script/corpus real-blog-r4 si-blog
export PATH="$(mise where ruby@4.0.7)/bin:$PATH"
(cd .corpus/si-blog && echo "gem \"concurrent-ruby\", path: \"$W/cr138\"" >> Gemfile && bundle install --quiet &&
  RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec rails db:prepare assets:precompile)
for v in fwd ref aaa; do
  cp -a .corpus/si-blog .corpus/si-blog-$v
  (cd .corpus/si-blog-$v && sed -i "s|$W/cr138\"|$W/cr138-$v\"|" Gemfile && bundle install --quiet)
done
for app in si-blog si-blog-ref; do
  RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 target/debug/lowrail build .corpus/$app --env production
done
export PATH=$W/valgrind-brk512/bin:$PATH CPATH=$W/valgrind-brk512/include
run() { # BASE VARIANT OUT
  RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=error BENCH_COUNTER=callgrind BENCH_HEAP_MODE=fixed \
    BENCH_JOBS=2 BENCH_VARIANT_APP="$PWD/.corpus/$2" ruby bench/request_pairs.rb ".corpus/$1" "$3" GET:/articles
}
run si-blog si-blog-fwd $W/si-bench-1
run si-blog-ref si-blog-fwd $W/si-bench-2
run si-blog-ref si-blog-aaa $W/si-bench-3
