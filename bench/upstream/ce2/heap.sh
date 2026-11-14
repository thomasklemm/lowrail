# Fixed heap floors from docs/bench.md (an experimental control, not a production
# setting); source before census, cpu-census or walltime runs you compare.
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000
export RUBY_GC_HEAP_1_INIT_SLOTS=250000
export RUBY_GC_HEAP_2_INIT_SLOTS=100000
export RUBY_GC_HEAP_3_INIT_SLOTS=20000
export RUBY_GC_HEAP_4_INIT_SLOTS=10000
