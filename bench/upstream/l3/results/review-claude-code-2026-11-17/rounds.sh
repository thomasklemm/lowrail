#!/bin/bash
# rounds.sh SCRIPT ROUNDS FLAGS TREE...: benchmark-ips SCRIPT on ~/ips/TREE, interleaved per round, pinned to core 1.
set -euo pipefail
script=$1; rounds=$2; flags=$3; shift 3
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH BUNDLE_PATH=$HOME/ips/gems
ruby $flags -v
for r in $(seq 1 "$rounds"); do
  for t in "$@"; do
    BUNDLE_GEMFILE=$HOME/ips/b-$t/Gemfile taskset -c 1 ruby $flags -rbundler/setup -e '
      require "active_record"
      abort "wrong tree" unless $LOADED_FEATURES.grep(%r{/active_record\.rb\z}).first.start_with?(File.expand_path("~/ips/#{ARGV[0]}/"))
      load ARGV[1]' "$t" "$script" | sed -n "s/^\( *[A-Za-z].*i\/s.*\)/$t r$r: \1/p"
  done
done
