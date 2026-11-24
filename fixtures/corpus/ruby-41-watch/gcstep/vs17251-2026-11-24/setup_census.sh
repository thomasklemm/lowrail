#!/bin/bash
# census5 Blog/Fizzy/Lobsters on Rails main 50c54eed06 (round 2's pin), master overlays, Ruby ~/w/r-master.
cd /home/user/workspace/repo
for a in blog fizzy lobsters; do
  [ -f .corpus/census5-$a/.census.json ] && continue
  rm -rf .corpus/census5-$a
  MAKEFLAGS=-j2 mise exec -- script/census setup --rails rails/rails@50c54eed06 --ruby ~/w/r-master \
    --ruby-overlays fixtures/corpus/frontier-master --apps $a --corpus census5 > ~/w/logs/setup-$a.log 2>&1
  echo "$(date +%T) setup $a rc=$?" >> ~/w/logs/setup.log
done
echo "$(date +%T) setup done" >> ~/w/logs/setup.log
exec sleep infinity
