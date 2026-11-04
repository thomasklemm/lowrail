#!/usr/bin/env bash
# usage: files.sh LANE LABEL COMPONENT FILE...
# Runs single test files of one component, each in its own process, as the
# component's rake task does, appending to LABEL/COMPONENT-files.log.
set -u
lane=$1 label=$2 comp=$3; shift 3
case $lane in
  m) rubybin=$HOME/rubies/master/bin rails=$HOME/src/rails-m ;;
  c) rubybin=$HOME/.local/share/mise/installs/ruby/4.0.9/bin rails=$HOME/src/rails-c ;;
esac
out=$HOME/src/runs/$label; mkdir -p "$out"
cd "$rails/$comp" || exit 1
for f in "$@"; do
  echo "--- $f" >> "$out/$comp-files.log"
  env PATH="$rubybin:$PATH" BUNDLE_PATH=$HOME/src/bundle \
    timeout ${LIMIT:-1200} bundle exec ruby -w -Itest -Ilib -I../activesupport/lib -I../actionpack/lib -I../actionview/lib -I../activemodel/lib "$f" --seed=${SEED:-4242} >> "$out/$comp-files.log" 2>&1
done
echo "$comp-files done" >> "$out/summary.txt"
