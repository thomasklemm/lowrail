#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/user/workspace/repo
WORK=$ROOT/.amp/in/orb-backup/l3-review-41af
OUT=$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-27/head-41af869c78
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.10/bin:$PATH BUNDLE_PATH=$WORK/gems TMPDIR=$WORK/tmp
for tree in main head; do
  export RAILS=$WORK/$tree BUNDLE_GEMFILE=$WORK/b-$tree/Gemfile
  (cd "$RAILS/activemodel"; ruby bin/test test/cases/attribute_set_test.rb test/cases/attributes_test.rb) > "$OUT/am-$tree.txt" 2>&1
  (cd "$RAILS/activerecord"; ruby bin/test --adapter sqlite3 test/cases/attribute_methods_test.rb test/cases/marshal_serialization_test.rb test/cases/message_pack_test.rb test/cases/dirty_test.rb test/cases/serialized_attribute_test.rb test/cases/encryption/encryptable_record_test.rb) > "$OUT/ar-$tree.txt" 2>&1
  ARCONN=sqlite3 RAILS_MINITEST_PLUGIN=true ruby -rbundler/setup -I"$WORK/head/activerecord/test" "$WORK/head/activerecord/test/cases/attribute_methods_test.rb" -n '/attributes_(for_database_serializes|before_type_cast_returns)_the_attributes_the_record_had/' > "$OUT/regressions-$tree.txt" 2>&1
  ruby -rbundler/setup "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-25/body_claims.rb" > "$OUT/body-claims-$tree.txt"
done
