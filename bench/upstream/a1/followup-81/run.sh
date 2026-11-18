#!/bin/bash
# run.sh NAME=RAILS_TREE...: every probe on each tree; output in raw/NAME.txt (SQLite) or raw/NAME-postgresql.txt
# with ADAPTER=postgresql DATABASE=<disposable database>.
cd "$(dirname "$0")"
suffix=${ADAPTER:+-$ADAPTER}
for arg in "$@"; do
  name=${arg%%=*} tree=${arg#*=}
  {
    for w in 16 17; do for k in 0 1; do echo "composite WIDTH=$w KEEP=$k: $(RAILS=$tree KEEP=$k WIDTH=$w ruby composite_serialization.rb 2>&1 | tail -1)"; done; done
    for w in 16 17; do echo "join WIDTH=$w:"; RAILS=$tree WIDTH=$w ruby join_serialization.rb 2>&1 | tail -2; done
    echo "scoped_join WIDTH=17:"; RAILS=$tree WIDTH=17 ruby scoped_join.rb 2>&1 | tail -2
    echo "linear_join:"; RAILS=$tree ruby linear_join.rb 2>&1 | tail -2
    for w in 16 17; do echo "range_join WIDTH=$w:"; RAILS=$tree WIDTH=$w ruby range_join.rb 2>&1 | tail -2; done
    echo "range_plain WIDTH=17:"; RAILS=$tree WIDTH=17 ruby range_plain.rb 2>&1 | tail -2
    echo "range_paths WIDTH=17:"; RAILS=$tree WIDTH=17 ruby range_paths.rb 2>&1 | tail -8
  } > raw/$name$suffix.txt
done
