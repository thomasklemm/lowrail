#!/usr/bin/env bash
# micro.sh OUT: per-call Ir of fragment.css("action-text-attachment") on nokogiri as installed, with the flat
# SelectorCache key and with the joined-XPath cache (req/ patches), each cell twice; 4.0.10 interp/YJIT, master interp/ZJIT.
here=$(cd "$(dirname "$0")" && pwd); ir=$here/../../gem_request_census/ir.sh; req=$here/../req; out=$1
r4010=$(~/.local/bin/mise where ruby@4.0.10)/bin; master=${MASTER_BIN:-$HOME/.rubies/master-zjit/bin}
for cfg in "4.0.10 interp|$r4010|" "4.0.10 yjit|$r4010|--yjit" "master interp|$master|" "master zjit|$master|--zjit"; do
  IFS='|' read -r name bin flags <<<"$cfg"
  v=$($bin/ruby -rnokogiri -e 'print Nokogiri::VERSION')
  for patch in "" noko_flatkey2.rb noko_cache.rb; do
    p=${patch:+$req/$patch}
    a=$(PATCH=$p RUBY_BIN=$bin RUBYFLAGS=$flags bash "$ir" /x "$here/micro.rb" 'F.css("action-text-attachment")' 2000 2000)
    b=$(PATCH=$p RUBY_BIN=$bin RUBYFLAGS=$flags bash "$ir" /x "$here/micro.rb" 'F.css("action-text-attachment")' 2000 2000)
    echo "$name|nokogiri $v|${patch:-base}|$a|$b" | tee -a "$out"
  done
done
