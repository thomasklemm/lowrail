#!/usr/bin/env bash
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
cd /tmp/x/rb-r81
PATH=/home/user/rubies/master/bin:$PATH ./run_benchmarks.rb --no-sudo --turbo --interleave -e "i409::/home/user/.local/share/mise/installs/ruby/4.0.9/bin/ruby" -e "y409::/home/user/.local/share/mise/installs/ruby/4.0.9/bin/ruby --yjit" -e "im::/home/user/rubies/master/bin/ruby" -e "ym::/home/user/rubies/master/bin/ruby --yjit" -e "zm::/home/user/rubies/master/bin/ruby --zjit" --out_path=/tmp/x/wall/jit-all --name_filters=blog,railsbench,lobsters > /tmp/x/wall/jit-all.txt 2>&1
echo "jit all exit $?" >> /tmp/x/wall/wall.log
