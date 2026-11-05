#!/bin/bash
# zcg.sh GEMFILE TAG N : cachegrind of the Zammad replay, N rounds after warm-up
cd /home/user/w/gems/zammad
. /tmp/gqscripts/zenv.sh
unset LD_PRELOAD
db=zr_${2//-/_}_$3; dropdb -h 127.0.0.1 -U postgres --if-exists $db; createdb -h 127.0.0.1 -U postgres -T zammad_replay $db
printf 'flush_all\r\n' > /dev/tcp/127.0.0.1/11212; redis-cli -n 3 flushdb >/dev/null
export REDIS_URL=redis://127.0.0.1:6379/3 MEMCACHE_SERVERS=127.0.0.1:11212 DATABASE_URL=postgres://postgres@127.0.0.1/$db BUNDLE_GEMFILE=$PWD/$1 RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
R=$(mise exec ruby@4.0.9 -- which ruby); export PATH=$(dirname $R):$PATH
valgrind --tool=cachegrind --cache-sim=no --trace-children=yes --cachegrind-out-file=/tmp/cg/$2.zammad.$3.%p.out $R bin/rails runner /home/user/workspace/repo/bench/upstream/graphql_ruby/apps/zammad-replay.rb run $3 > /tmp/cg/$2.zammad.$3.log 2>&1
grep -h "summary\|I *refs" /tmp/cg/$2.zammad.$3.log | tail -1
dropdb -h 127.0.0.1 -U postgres $db
