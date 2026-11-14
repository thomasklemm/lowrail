#!/usr/bin/env bash
# A/A matrix in two lanes (railsbench reseeds a shared SQLite file, so its runs stay sequential).
cd /home/user/work/cg
P=/home/user/work/vg/brk512/bin/valgrind
FH="RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000"
one() { local b=$1 tag=$2 mode=$3 d=$1; [ $b = railsbench ] && d=rb
  case $mode in
    P) VALGRIND=$P ./run1.sh $b $PWD/$d $tag ;;
    FH) VG_ENV="$FH" ./run1.sh $b $PWD/$d $tag ;;
    Y) WARMUP_ITRS=10 ./run1.sh $b $PWD/$d $tag --yjit ;;
    *) ./run1.sh $b $PWD/$d $tag ;;
  esac; }
( for i in 2 3 4; do one railsbench s$i; done; for i in 1 2 3; do one railsbench p$i P; done
  for i in 1 2 3; do one railsbench f$i FH; done; for i in 1 2 3; do one railsbench y$i Y; done ) > laneA.out 2>&1 &
( for i in 1 2 3 4; do one fib s$i; done; for i in 1 2 3 4; do one lobsters s$i; done
  for i in 1 2 3; do one lobsters p$i P; done ) > laneB.out 2>&1 &
wait; echo done >> laneA.out
