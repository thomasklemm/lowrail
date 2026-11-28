#!/usr/bin/env bash
# The new Message spec (and optionally the whole suite) on base and head of slack-ruby-client for each hashie version.
# Usage: hashie-matrix.sh RUBY_VERSION [full] -- VERSIONS...
set -uo pipefail
rv=$1; shift; full=""; [ "$1" = full ] && { full=1; shift; }; shift
bin=$HOME/.local/share/mise/installs/ruby/$rv/bin
for v in "$@"; do
  for tree in slack-base slack-ruby-client; do
    g=/tmp/slackg/$rv/$v/$tree; mkdir -p $g
    printf "eval_gemfile '%s/w/%s/Gemfile'\ngem 'hashie', '= %s'\n" "$HOME" "$tree" "$v" > $g/Gemfile
    ( cd $HOME/w/$tree
      export PATH=$bin:$PATH BUNDLE_GEMFILE=$g/Gemfile BUNDLE_PATH=$HOME/w/bundle-slack-$rv BUNDLE_APP_CONFIG=$g/.bundle
      if ! bundle install --jobs 4 > $g/bundle.log 2>&1; then echo "ruby $rv hashie $v $tree: bundle failed: $(grep -m1 -i 'error\|could not\|conflict' $g/bundle.log | cut -c1-160)"; exit; fi
      got=$(bundle exec ruby -e 'require "hashie"; print Hashie::VERSION' 2>/dev/null)
      bundle exec rspec spec/slack/messages/message_spec.rb > $g/spec.log 2>&1
      line="ruby $rv hashie $got $tree: new spec $(grep -E 'examples?, ' $g/spec.log | tail -1)$(grep -m1 -E 'NoMethodError|NameError|LoadError' $g/spec.log | cut -c1-120)"
      if [ -n "$full" ]; then bundle exec rake spec > $g/full.log 2>&1; line="$line; suite $(grep -E 'examples, ' $g/full.log | tail -1)"; fi
      echo "$line" )
  done
done
