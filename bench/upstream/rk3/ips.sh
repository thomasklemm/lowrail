#!/usr/bin/env bash
# ips.sh MAIN_LIB BRANCH_LIB OUTDIR [yjit]: ROUNDS (default 3) alternating rounds of ips.rb on CPU ${CPU:-1}.
cd "$(dirname "$0")"
R=${RUBY_BIN:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin}/ruby; flag=; [ "$4" = yjit ] && flag=--yjit
mkdir -p "$3"
for r in $(seq 1 ${ROUNDS:-3}); do
  for side in main:$1 branch:$2; do
    OUT="$3/${side%%:*}-${4:-interp}-$r.json" taskset -c ${CPU:-1} $R $flag -I "${side#*:}" ips.rb
  done
done
