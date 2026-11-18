#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
here="$root/bench/upstream/a1/review-thermos-sol-e6bfe76e95"
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH"
export HEAD_RAILS="$root/.amp/in/orb-backup/rails"
for pair in "$@"; do
  name=${pair%%=*}
  export RAILS=${pair#*=}
  for adapter in sqlite3 postgresql; do
    for keep in 0 1; do
      result=0
      ARCONN=$adapter KEEP=$keep ruby -w "$here/targeted_test.rb" > "$here/raw/targeted-$name-$adapter-$keep.txt" 2>&1 || result=$?
      echo "exit $result" >> "$here/raw/targeted-$name-$adapter-$keep.txt"
    done
  done
done
