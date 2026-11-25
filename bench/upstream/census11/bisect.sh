#!/usr/bin/env bash
# Bisect the association-reader growth from census 10 to main over first-parent AR/AM merges.
cd /home/user/workspace/repo
trees="c10"; for s in 0352162173 9a64d012d2 a266a4e635 f12b615776 e22f32a760 9f2a064cd4 b412d7a95e 6ef561e024 a368b4c966 dbde2f8182 69c6c55e86 79fccbfc53 e49b3461cd; do trees="$trees b-$s"; done
MODES=interp TAG=-bis CASES="has_many has_one belongs_to joins_has_many has_many_through" bash bench/upstream/census10/sweep.sh bench/upstream/census10/assoc_micro.rb docs/upstream/data/rails-main-census-11/raw/bisect $trees main
echo BISECTDONE; sleep infinity
