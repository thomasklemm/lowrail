#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH"
E="$PWD/docs/upstream/data/rails-main-census-9/lead6/review-astra-2026-11-27"

# Run from Lowrail's root after creating the two detached worktrees and installing the retained Gemfiles.
python3 "$E/audit_numbers.py" > "$E/numbers.txt"
for side in base head; do
  export BUNDLE_GEMFILE="$PWD/.amp/in/orb-backup/l6-review/Gemfile-$side"
  ruby bench/upstream/k1/keys_probe.rb > "$E/keys-$side.txt"
  ruby docs/upstream/data/rails-main-census-9/lead6/rebuild-2026-11-27/l6_keys_callers.rb > "$E/callers-$side.txt"
  ruby "$E/probe.rb" > "$E/probe-$side.jsonl"
  ruby -rbundler/setup \
    -I ".amp/in/orb-backup/l6-review/$side/railties/lib:.amp/in/orb-backup/l6-review/$side/activemodel/test" \
    ".amp/in/orb-backup/l6-review/$side/activemodel/test/cases/attribute_set_test.rb" > "$E/test-$side.log" 2>&1
done
diff -u "$E/keys-base.txt" "$E/keys-head.txt" > "$E/keys.diff"
diff -u "$E/probe-base.jsonl" "$E/probe-head.jsonl" > "$E/probe.diff" || test $? = 1

for round in 1 2 3; do
  for side in base head base2; do
    tree=${side/base2/base}
    BUNDLE_GEMFILE="$PWD/.amp/in/orb-backup/l6-review/Gemfile-$tree" \
      taskset -c 1 ruby --yjit "$E/ips.rb" > "$E/ips-$round-$side.log" 2>&1
  done
done
