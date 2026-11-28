#!/usr/bin/env bash
# Runs repro.rb (the reviewers' cases: selective warnings, quiet, a raising logger, a frozen subclass, Ractors) on
# master with the new spec (slack-base) and on the head, per hashie version. Usage: repro.sh RUBY VERSIONS...
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); rv=$1; shift; bin=$HOME/.local/share/mise/installs/ruby/$rv/bin
for v in "$@"; do
  for tree in slack-base slack-ruby-client; do
    g=/tmp/slackg/$rv/$v/$tree; mkdir -p $g
    printf "eval_gemfile '%s/w/%s/Gemfile'\ngem 'hashie', '= %s'\n" "$HOME" "$tree" "$v" > $g/Gemfile
    ( cd $HOME/w/$tree; export PATH=$bin:$PATH BUNDLE_GEMFILE=$g/Gemfile BUNDLE_PATH=$HOME/w/bundle-slack-$rv BUNDLE_APP_CONFIG=$g/.bundle
      if ! bundle install --jobs 4 > $g/bundle.log 2>&1; then echo "== ruby $rv hashie $v $([ $tree = slack-base ] && echo base || echo head): bundle failed"; exit; fi
      echo "== ruby $rv hashie $v $([ $tree = slack-base ] && echo base || echo head)"; bundle exec ruby -W0 -I lib $here/repro.rb 2>/dev/null | cut -c1-140 )
  done
done
