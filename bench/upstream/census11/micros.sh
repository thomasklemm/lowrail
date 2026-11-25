#!/usr/bin/env bash
cd /home/user/workspace/repo
out=docs/upstream/data/rails-main-census-11/raw
for s in census10/assoc_micro census10/rel_micro census9/req_micro census9/attr_micro census9/where_micro; do
  bash bench/upstream/census10/sweep.sh bench/upstream/$s.rb $out/$(basename $s) s81 c10 main main2
done
echo MICROSDONE; sleep infinity
