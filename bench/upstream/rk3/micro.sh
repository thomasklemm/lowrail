#!/usr/bin/env bash
# micro.sh MAIN_LIB BRANCH_LIB [yjit]: Callgrind Ir per call for each line of micro_exprs.txt, rack main / branch,
# and main twice as the A/A.
cd "$(dirname "$0")"
export RUBY_BIN=${RUBY_BIN:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin}
[ "$3" = yjit ] && export RUBYFLAGS=--yjit
ir=../gem_request_census/ir.sh
while IFS= read -r e; do
  a=$(bash $ir "$1" "$PWD/micro.rb" "$e" 2000 500); a2=$(bash $ir "$1" "$PWD/micro.rb" "$e" 2000 500)
  b=$(bash $ir "$2" "$PWD/micro.rb" "$e" 2000 500)
  echo "${3:-interp}|$e|$a|$a2|$b"
done < micro_exprs.txt
