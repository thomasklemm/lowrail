#!/usr/bin/env bash
# mutants_by_assert.sh: for each /tmp/mut/* (made by mutants.rb), the assertions that fail when evaluated one by one.
here=$(cd "$(dirname "$0")" && pwd)
for d in /tmp/mut/*/; do
  for run in "4.0.10|" "4.0.10 no-C|-r$here/no_c_decoder.rb" "2.5.9|" "truffleruby-40.0.0|"; do
    IFS='|' read -r name pre <<<"$run"
    ruby=$(mise where ruby@${name%% *})/bin/ruby
    o=$(cd $d && $ruby $pre -Ilib -Itest/lib $here/eval_asserts.rb $here/asserts.rb 2>&1); s=$?; r=$(echo "$o" | tail -1); [ $s -ne 0 ] && r="process died: $(echo "$o" | grep -a -m1 -o "[A-Za-z.]*Exception\|[A-Z][a-zA-Z]*Error")"
    echo "$(basename $d) | $name | $r"
  done
done
