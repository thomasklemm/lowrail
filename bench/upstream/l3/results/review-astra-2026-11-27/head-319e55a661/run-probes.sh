set -euo pipefail
source .amp/in/orb-backup/l3-review/env.sh
export OUT="$ROOT/bench/upstream/l3/results/review-astra-2026-11-27/head-319e55a661"
OLD="$ROOT/bench/upstream/l3/results/review-astra-2026-11-27"
PROBE="$OLD/head-41af869c78/defaults_and_caches.rb"
export TMPDIR="$WORK/helper-tmp"
mkdir -p "$TMPDIR"
tar -xzf "$OLD/head-41af869c78/payload-inputs.tar.gz" -C "$TMPDIR" rails_6_1_topic.dump rails_6_1_new_topic.dump rails_6_1_topic_associations.dump
for tree in base head; do
  use_tree "$tree"
  ruby "$PROBE" > "$OUT/caches-$tree.jsonl"
  ruby --yjit "$PROBE" > "$OUT/caches-$tree-yjit.jsonl"
  ruby "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-25/exactness_extension.rb" > "$OUT/extended-$tree.txt"
  ruby "$OLD/adversary.rb" > "$OUT/adversary-$tree.jsonl"
  ruby "$OLD/ciphertext.rb" > "$OUT/ciphertext-$tree.jsonl"
  ruby "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-27/callable_default_repro.rb" > "$OUT/default-repro-$tree.txt"
  ruby "$ROOT/bench/upstream/l3/probe.rb" dump "$TMPDIR/payload-$tree" > "$OUT/payload-dump-$tree.txt"
  ARCONN=sqlite3 RUBYLIB="$RUBYLIB:$RAILS/activerecord/test" ruby "$OLD/legacy.rb" > "$OUT/legacy-$tree.txt"
  grep '^LEGACY ' "$OUT/legacy-$tree.txt" > "$OUT/legacy-$tree.jsonl"
  bundle exec rake -C "$RAILS/activerecord" test:sqlite3 TEST='test/cases/attribute_methods_test.rb,test/cases/marshal_serialization_test.rb,test/cases/message_pack_test.rb,test/cases/dirty_test.rb,test/cases/encryption/encryptable_record_test.rb' > "$OUT/suite-$tree.txt" 2>&1
done
for tree in base head; do
  use_tree "$tree"
  ruby "$ROOT/bench/upstream/l3/probe.rb" probe "$TMPDIR/payload-base" "$TMPDIR/payload-head" > "$OUT/payload-$tree.txt"
done
for kind in caches extended adversary ciphertext default-repro payload legacy; do
  ext=txt
  [[ "$kind" == caches || "$kind" == adversary || "$kind" == ciphertext || "$kind" == legacy ]] && ext=jsonl
  cmp "$OUT/$kind-base.$ext" "$OUT/$kind-head.$ext"
  wc -l "$OUT/$kind-head.$ext"
done
cmp "$OUT/caches-base-yjit.jsonl" "$OUT/caches-head-yjit.jsonl"
cmp "$OUT/caches-head.jsonl" "$OUT/caches-head-yjit.jsonl"
echo 'All comparisons identical'
