#!/usr/bin/env bash
# micro_cgi.sh OUT: per-call Ir of UR1.decode_cgi (micro_cgi.rb), each cell twice, as micro.sh.
here=$(cd "$(dirname "$0")" && pwd); ir=$here/../../gem_request_census/ir.sh; out=$1
r4010=$(~/.local/bin/mise where ruby@4.0.10)/bin; master=${MASTER_BIN:-$HOME/.rubies/master-zjit/bin}
for cfg in "4.0.10 interp|$r4010|" "4.0.10 yjit|$r4010|--yjit" "master interp|$master|" "master zjit|$master|--zjit"; do
  IFS='|' read -r name bin flags <<<"$cfg"
  for in in plain key spaces cookie; do
    expr="UR1.decode_cgi(S)"
    a=$(IN=$in RUBY_BIN=$bin RUBYFLAGS=$flags bash "$ir" /x "$here/micro_cgi.rb" "$expr" 5000 3000)
    b=$(IN=$in RUBY_BIN=$bin RUBYFLAGS=$flags bash "$ir" /x "$here/micro_cgi.rb" "$expr" 5000 3000)
    echo "$name|$in|$expr|$a|$b" | tee -a "$out"
  done
done
