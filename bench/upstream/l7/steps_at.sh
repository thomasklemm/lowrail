# steps_at.sh OUTDIR COMMIT...: steps.rb under Callgrind at each commit (worktree ~/l7/bis2)
set -u
out=$1; shift; mkdir -p $out
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
for c in "$@"; do
  git -C $HOME/l7/bis2 checkout -q --detach $c
  GEM_PATH=$HOME/l7/gems/ruby/4.0.0 RAILS=$HOME/l7/bis2 WIDTH=${WIDTH:-15} $HOME/c8-valgrind/bin/valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null \
    $HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby /home/user/workspace/repo/bench/upstream/l7/steps.rb > $out/$c.txt 2>/dev/null
done
