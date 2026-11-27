#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/user/workspace/repo
WORK=$ROOT/.amp/in/orb-backup/l3-review-319e
PREVIOUS=$ROOT/.amp/in/orb-backup/l3-review-41af
OUT=$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-27/head-319e55a661
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.10/bin:$PATH
export BUNDLE_PATH=$PREVIOUS/gems TMPDIR=$WORK/tmp
for adapter in sqlite3 postgresql; do
  for tree in main head; do
    export RAILS=$WORK/head BUNDLE_GEMFILE=$WORK/b-head/Gemfile ADAPTER=$adapter
    if [ "$tree" = main ]; then
      export RAILS=$PREVIOUS/main BUNDLE_GEMFILE=$PREVIOUS/b-main/Gemfile
    fi
    for mode in interp yjit; do
      flags=()
      [ "$mode" != yjit ] || flags=(--yjit)
      ruby "${flags[@]}" "$ROOT/bench/upstream/l3/review_probe.rb" > "$OUT/probe-$tree-$adapter-$mode.txt"
      ruby "${flags[@]}" "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-25/exactness_extension.rb" > "$OUT/extended-$tree-$adapter-$mode.txt"
      ruby "${flags[@]}" "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-27/callable_default_repro.rb" > "$OUT/default-$tree-$adapter-$mode.txt"
    done
  done
done
for adapter in sqlite3 postgresql; do
  for mode in interp yjit; do
    for probe in probe extended default; do
      cmp "$OUT/$probe-main-$adapter-$mode.txt" "$OUT/$probe-head-$adapter-$mode.txt"
      wc -l "$OUT/$probe-main-$adapter-$mode.txt"
    done
  done
done > "$OUT/probe-comparison.txt"
for tree in main head; do
  export RAILS=$WORK/head BUNDLE_GEMFILE=$WORK/b-head/Gemfile
  if [ "$tree" = main ]; then
    export RAILS=$PREVIOUS/main BUNDLE_GEMFILE=$PREVIOUS/b-main/Gemfile
  fi
  (cd "$RAILS/activemodel"; ruby bin/test test/cases/attribute_set_test.rb test/cases/attributes_test.rb) > "$OUT/am-$tree.txt" 2>&1
  (cd "$RAILS/activerecord"; ruby bin/test --adapter sqlite3 test/cases/attribute_methods_test.rb test/cases/marshal_serialization_test.rb test/cases/message_pack_test.rb test/cases/dirty_test.rb test/cases/serialized_attribute_test.rb test/cases/encryption/encryptable_record_test.rb) > "$OUT/ar-$tree.txt" 2>&1
  ARCONN=sqlite3 RAILS_MINITEST_PLUGIN=true ruby -rbundler/setup -I"$WORK/head/activerecord/test" "$WORK/head/activerecord/test/cases/attribute_methods_test.rb" -n '/attributes_(for_database_serializes|before_type_cast_returns)_the_attributes_the_record_had/' > "$OUT/regressions-$tree.txt" 2>&1
  ruby "$ROOT/bench/upstream/l3/concurrency_probe.rb" > "$OUT/concurrency-$tree.txt" 2>&1
done
for tree in main head main2; do
  export RAILS=$PREVIOUS/main BUNDLE_GEMFILE=$PREVIOUS/b-main/Gemfile
  if [ "$tree" = head ]; then
    export RAILS=$WORK/head BUNDLE_GEMFILE=$WORK/b-head/Gemfile
  fi
  ruby -rbundler/setup "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-25/body_claims.rb" > "$OUT/body-claims-$tree.txt"
done
printf '%s\n' 'Differential probes, focused tests, concurrency and body claims completed.'
