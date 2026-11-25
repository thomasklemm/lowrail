#!/bin/bash
# ips_rounds.sh SCRIPT FIX ROUNDS [RUBY_FLAGS]: benchmark-ips SCRIPT on ~/ips/main, ~/ips/FIX and ~/ips/main2
# (a second checkout of main, the A/A), interleaved per round, pinned to core 1, Ruby 4.0.9.
set -euo pipefail
script=$1; fix=$2; rounds=$3; flags=${4:-}
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH BUNDLE_PATH_UNUSED=1
ruby $flags -v
for r in $(seq 1 "$rounds"); do
  for t in main "$fix" main2; do
    BUNDLE_GEMFILE=$HOME/ips/b-$t/Gemfile taskset -c 1 ruby $flags -rbundler/setup -e '
      require "active_record"
      abort "wrong tree" unless $LOADED_FEATURES.grep(%r{/active_record\.rb\z}).first.start_with?(File.realpath(File.expand_path("~/ips/#{ARGV[0]}")))
      load ARGV[1]' "$t" "$script" | sed -n "s/^\( *[A-Za-z].*i\/s.*\)/$t r$r: \1/p"
  done
done
