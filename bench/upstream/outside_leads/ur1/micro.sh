#!/usr/bin/env bash
# micro.sh OUT: per-call Ir of URI.decode/encode_www_form_component and UR1's decoder, each cell twice (A/A),
# on Ruby 4.0.10 (interpreter, YJIT) and master (ZJIT). Uses ir.sh (GC off, (Ir(N)-Ir(0))/N).
here=$(cd "$(dirname "$0")" && pwd); ir=$here/../../gem_request_census/ir.sh; out=$1
r4010=$(~/.local/bin/mise where ruby@4.0.10)/bin; master=${MASTER_BIN:-$HOME/.rubies/master-zjit/bin}
for cfg in "4.0.10 interp|$r4010|" "4.0.10 yjit|$r4010|--yjit" "master interp|$master|" "master zjit|$master|--zjit"; do
  IFS='|' read -r name bin flags <<<"$cfg"
  for in in plain key spaces cookie; do
    for expr in "URI.decode_www_form_component(S)" "UR1.decode(S)" "URI.encode_www_form_component(S)"; do
      a=$(IN=$in RUBY_BIN=$bin RUBYFLAGS=$flags bash "$ir" /nonexistent "$here/micro.rb" "$expr" 5000 3000)
      b=$(IN=$in RUBY_BIN=$bin RUBYFLAGS=$flags bash "$ir" /nonexistent "$here/micro.rb" "$expr" 5000 3000)
      echo "$name|$in|$expr|$a|$b" | tee -a "$out"
    done
  done
done
