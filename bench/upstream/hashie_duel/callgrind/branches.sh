#!/usr/bin/env bash
# Builds the Duel --callgrind calibration branches on thomasklemm/hashie, each one commit on cg-calibration
# (or cg-calibration-pre656 for the #656 candidate), and opens a PR inside the fork (never upstream).
# Recipes are HD1's (bench/upstream/hashie_duel/calibration-branches.sh), as rebuilt for round 6 on bcf21e7.
set -euo pipefail
cd /home/user/src/hashie
COMMIT=/home/user/workspace/repo/script/commit
git fetch -q origin cg-calibration
base_branch=cg-calibration

make_branch() { # name title body edit-command...
  local name=$1 title=$2 body=$3
  shift 3
  git checkout -q -B "cg/$name" "origin/$base_branch"
  "$@"
  git diff --quiet HEAD -- lib && { echo "no change for $name" >&2; exit 1; }
  git add -A lib
  printf '%s\n\n%s\n' "$title" "$body" > /tmp/cg-msg.txt
  "$COMMIT" -F /tmp/cg-msg.txt > /dev/null
  git push -q -f origin "HEAD:refs/heads/cg/$name"
  gh pr create -R thomasklemm/hashie --base "$base_branch" --head "cg/$name" --title "[callgrind calibration] $title" \
    --body "Duel --callgrind calibration run on the fork: $body" | tail -1
}

aa_comment() { # file anchor comment
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
  make_branch plant-alloc "Plant: convert_key back to Symbol#to_s" "planted regression, convert_key allocates a String per Symbol key again." \
    sed -i 's/return key.name if key.is_a?(Symbol)/return key.to_s if key.is_a?(Symbol)/' lib/hashie/mash.rb
  ;;
plant-cpu)
  make_branch plant-cpu "Plant: method_missing checks key? three times" "planted CPU-only regression in method access, no extra allocation." \
    sed -i 's/      return self.\[\](method_name, \&blk) if key?(method_name)/      return self.[](method_name, \&blk) if key?(method_name) \&\& key?(method_name) \&\& key?(method_name)/' lib/hashie/mash.rb
  ;;
pre656)
  # Base for the known improvement: lib/hashie/mash.rb as it was before #656 (812c48c^).
  git checkout -q -B cg-calibration-pre656 origin/cg-calibration
  git checkout 812c48c^ -- lib/hashie/mash.rb
  git add lib/hashie/mash.rb
  printf 'Calibration base: lib/ before the Mash respond_to_missing? change\n\nlib/hashie/mash.rb of 812c48c^, so the candidate branch brings #656 back as a known improvement.\n' > /tmp/cg-msg.txt
  "$COMMIT" -F /tmp/cg-msg.txt > /dev/null
  git push -q -f origin cg-calibration-pre656
  ;;
hm1)
  base_branch=cg-calibration-pre656
  git fetch -q origin cg-calibration-pre656
  make_branch hm1 "Candidate: write new Mash keys without allocating in respond_to_missing?" "lib/hashie/mash.rb of 812c48c (#656), a known improvement: faster or the same, never slower." \
    git checkout 812c48c -- lib/hashie/mash.rb
  ;;
*) echo "usage: $0 aa|plant-alloc|plant-cpu|pre656|hm1" >&2; exit 2 ;;
esac
git checkout -q cg-calibration
