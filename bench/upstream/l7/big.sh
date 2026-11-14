set -u
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
for w in 6 30 300; do for t in s81 main; do
  GEM_PATH=$HOME/l7/gems/ruby/4.0.0 RAILS=$HOME/l7/$t CASES="inst fresh" ROWS="${BIGROWS:-2000}" ITEMS=${BIGROWS:-2000} WIDTH=$w N=3 $HOME/c8-valgrind/bin/valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null \
    $HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby /home/user/workspace/repo/bench/upstream/l7/load_micro.rb 2>/dev/null | sed "s/^/$t /" >> $HOME/l7/big.txt
done; done
