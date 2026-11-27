#!/usr/bin/env bash
# Builds the Duel calibration branches on thomasklemm/hashie, each one commit on duel-calibration,
# and opens a PR against duel-calibration in the fork itself (never upstream).
# Titles, bodies and commit messages name no upstream PR or issue (no owner/repo#N, no URLs): each mention puts a
# cross-reference event on the upstream timeline. Use the item ID or plain words.
set -euo pipefail
cd /home/user/workspace/repos/hashie
COMMIT=/home/user/workspace/repo/script/commit
base=$(git rev-parse fork/duel-calibration)

make_branch() { # name title message-file-body edit-command
  local name=$1 title=$2 body=$3
  shift 3
  git checkout -q -B "calib/$name" "$base"
  "$@"
  git diff --quiet HEAD -- lib && { echo "no change for $name" >&2; exit 1; }
  git add -A lib
  printf '%s\n\n%s\n' "$title" "$body" > /tmp/calib-msg.txt
  "$COMMIT" -F /tmp/calib-msg.txt > /dev/null
  git push -q -f fork "HEAD:refs/heads/calib/$name"
  gh pr create -R thomasklemm/hashie --base duel-calibration --head "calib/$name" --title "[calibration] $title" --body "Duel calibration run on the fork: $body" | tail -1
}

aa_comment() { # file line-pattern comment
  python3 - "$@" <<'EOF'
import sys
path, anchor, comment = sys.argv[1:]
s = open(path).read()
i = s.index(anchor)
line_start = s.rindex('\n', 0, i) + 1
indent = s[line_start:i]
s = s[:line_start] + indent + '# ' + comment + '\n' + s[line_start:]
open(path, 'w').write(s)
EOF
}

case "${1:-}" in
aa)
  for n in 1 2 3 4 5; do
    case $n in
      1) f=lib/hashie/mash.rb; a='def respond_to_missing?' ;;
      2) f=lib/hashie/mash.rb; a='def _log_collision?' ;;
      3) f=lib/hashie/mash.rb; a='def convert_value' ;;
      4) f=lib/hashie/dash.rb; a='def initialize_attributes' ;;
      5) f=lib/hashie/mash.rb; a='def method_missing' ;;
    esac
    make_branch "aa-$n" "A/A control $n: a comment in $f" "no behaviour change, a comment only (A/A control $n)." \
      aa_comment "$f" "$a" "A/A control $n: this comment changes nothing."
  done
  ;;
plant-alloc)
  # #613's Symbol#name in convert_key reverted to to_s: one String per Symbol key conversion.
  make_branch plant-alloc "Plant: convert_key back to Symbol#to_s" "planted regression, convert_key allocates a String per Symbol key again." \
    sed -i 's/return key.name if key.is_a?(Symbol)/return key.to_s if key.is_a?(Symbol)/' lib/hashie/mash.rb
  ;;
plant-cpu)
  # No allocation: method_missing asks key? three times instead of once for a stored key.
  make_branch plant-cpu "Plant: method_missing checks key? three times" "planted CPU-only regression in method access, no extra allocation." \
    sed -i 's/      return self.\[\](method_name, \&blk) if key?(method_name)/      return self.[](method_name, \&blk) if key?(method_name) \&\& key?(method_name) \&\& key?(method_name)/' lib/hashie/mash.rb
  ;;
hm1)
  make_branch hm1 "Candidate: write new Mash keys without allocating in respond_to_missing?" "the lib change of fork commit d874851d79 (Mash respond_to_missing? allocations), which should be faster or the same." \
    git checkout fork/thomasklemm/respond-to-missing-allocations -- lib/hashie/mash.rb
  ;;
*) echo "usage: $0 aa|plant-alloc|plant-cpu|hm1" >&2; exit 2 ;;
esac
git checkout -q thomasklemm/duel
