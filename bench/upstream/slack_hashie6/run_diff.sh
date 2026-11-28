#!/usr/bin/env bash
# Runs message_diff.rb on base and head for each hashie version and prints what differs. Usage: run_diff.sh RUBY VERSIONS...
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); rv=$1; shift
bin=$HOME/.local/share/mise/installs/ruby/$rv/bin
for v in "$@"; do
  for tree in slack-base slack-ruby-client; do
    g=/tmp/slackg/$rv/$v/$tree
    ( cd $HOME/w/$tree && PATH=$bin:$PATH BUNDLE_GEMFILE=$g/Gemfile BUNDLE_PATH=$HOME/w/bundle-slack-$rv BUNDLE_APP_CONFIG=$g/.bundle \
        bundle exec ruby -W0 -I lib $here/message_diff.rb > $here/out/diff-ruby$rv-hashie$v-$([ $tree = slack-base ] && echo base || echo head).txt 2>/dev/null )
  done
  b=$here/out/diff-ruby$rv-hashie$v-base.txt; h=$here/out/diff-ruby$rv-hashie$v-head.txt
  rows=$(grep -vc '^class\|^ractor' $b)
  differ=$(diff <(grep -v '^class\|^ractor' $b) <(grep -v '^class\|^ractor' $h) | grep -c '^<')
  only_log=$(diff <(grep -v '^class\|^ractor' $b | sed -E 's/ \| warnings [0-9+]+$//') <(grep -v '^class\|^ractor' $h | sed -E 's/ \| warnings [0-9+]+$//') | grep -c '^<')
  echo "ruby $rv hashie $v: $rows rows, $differ differ, $only_log differ apart from the warning count; head rows with warnings: $(grep -v '^class\|^ractor' $h | grep -vc 'warnings 0+0$\|warnings 0$')"
  diff <(grep '^class\|^ractor' $b) <(grep '^class\|^ractor' $h) | sed 's/^/    /' | cut -c1-230
done
