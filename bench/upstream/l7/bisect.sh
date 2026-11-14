#!/bin/bash
# bisect.sh WORKTREE OUT COMMIT...: per-row Ir of a load_micro.rb case (CASE, default fresh) (ROWS rows, WIDTH columns,
# SQLite, interpreter) for each COMMIT, checked out in WORKTREE; appends "sha Ir/row obj/row" to OUT.
set -u
wt=$1 out=$2; shift 2
here=$(cd "$(dirname "$0")" && pwd)
ruby=${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby}
vg=${VALGRIND_PREFIX:-$HOME/c8-valgrind}/bin/valgrind
rows=${ROWS:-100}
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
for c in "$@"; do
  git -C "$wt" checkout -q --detach "$c" || continue
  line=$(GEM_PATH=${GEM_PATH:-$HOME/l7/gems/ruby/4.0.0} RAILS=$wt CASES=${CASE:-fresh} ROWS=$rows WIDTH=${WIDTH:-15} N=${N:-40} \
    $vg --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null "$ruby" "$here/load_micro.rb" 2>/dev/null)
  set -- $line
  echo "$(git -C "$wt" rev-parse --short=10 HEAD) $(git -C "$wt" log -1 --format=%cs HEAD) ${4:+$(awk -v i="$4" -v o="$5" -v r="$rows" 'BEGIN { printf "%.1f %.2f", i / r, o / r }')}" >> "$out"
done
