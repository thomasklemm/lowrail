set -euo pipefail
source .amp/in/orb-backup/l3-review/env.sh
OLD="$ROOT/bench/upstream/l3/results/review-astra-2026-11-27"
for tree in base head; do
  use_tree "$tree"
  ruby "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-25/exactness_extension.rb" > "$OUT/extended-$tree.txt"
  ruby "$OLD/adversary.rb" > "$OUT/adversary-$tree.jsonl"
  ruby "$OLD/ciphertext.rb" > "$OUT/ciphertext-$tree.jsonl"
  ruby "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-27/callable_default_repro.rb" > "$OUT/default-repro-$tree.txt"
  ruby "$ROOT/bench/upstream/l3/probe.rb" dump "$TMPDIR/payload-$tree" > "$OUT/payload-dump-$tree.txt"
  bundle exec rake -C "$RAILS/activerecord" test:sqlite3 TEST='test/cases/attribute_methods_test.rb,test/cases/marshal_serialization_test.rb,test/cases/message_pack_test.rb,test/cases/dirty_test.rb,test/cases/encryption/encryptable_record_test.rb' > "$OUT/suite-$tree.txt" 2>&1
done
for tree in base head; do
  use_tree "$tree"
  ruby "$ROOT/bench/upstream/l3/probe.rb" probe "$TMPDIR/payload-base" "$TMPDIR/payload-head" > "$OUT/payload-$tree.txt"
done
for kind in extended adversary ciphertext default-repro payload; do
  ext=txt; [[ "$kind" == adversary || "$kind" == ciphertext ]] && ext=jsonl
  diff -u "$OUT/$kind-base.$ext" "$OUT/$kind-head.$ext" > "$OUT/$kind.diff"
  wc -l "$OUT/$kind-base.$ext"
done
