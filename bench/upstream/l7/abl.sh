set -u
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
for w in ${WIDTHS:-15}; do for t in "$@"; do
  GEM_PATH=$HOME/l7/gems/ruby/4.0.0 RAILS=$HOME/l7/$t CASES="inst fresh" ROWS="10 100" WIDTH=$w N=40 $HOME/c8-valgrind/bin/valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null \
    $HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby /home/user/workspace/repo/bench/upstream/l7/load_micro.rb 2>/dev/null | sed "s/^/$t /" >> $HOME/l7/abl.txt
done; done
