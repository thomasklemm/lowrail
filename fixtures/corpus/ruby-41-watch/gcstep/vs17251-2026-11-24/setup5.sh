#!/bin/bash
# setup.sh: census5 Blog/Fizzy/Lobsters on Rails main 50c54eed06 (round 2's pin) with ~/w/r-master, Ruby overlays
# ~/w/overlays (frontier-master + round 2's Fizzy uuid patch and Lobsters typedstore initializer), then the
# shipit bundle. old/new/mg share master's gem dir (same revision, only gc/default/default.c differs); m760 bundles
# its own. Also builds gcmajors.so per Ruby. Log ~/w/logs/setup.log.
cd /home/user/workspace/repo
log=~/w/logs/setup.log
# Ruby overlays: frontier-master's, with round 2's Fizzy uuid patch appended and its Lobsters initializer as a new file.
F=fixtures/corpus/frontier-master R=fixtures/corpus/ruby-master-round-2
mkdir -p ~/w/overlays && cp $F/blog.patch ~/w/overlays/
cat $F/fizzy.patch $R/fizzy-rails-main-uuid.patch > ~/w/overlays/fizzy.patch
{ cat $F/lobsters.patch; f=config/initializers/census_typedstore_rails_main.rb
  printf 'diff --git a/%s b/%s\nnew file mode 100644\n--- /dev/null\n+++ b/%s\n@@ -0,0 +1,%d @@\n' $f $f $f $(wc -l < $R/${f##*/})
  sed 's/^/+/' $R/${f##*/}; } > ~/w/overlays/lobsters.patch
until [ -x ~/w/r-master/bin/ruby ]; do sleep 30; done
for a in blog fizzy lobsters; do
  [ -f .corpus/census5-$a/.census.json ] && continue
  rm -rf .corpus/census5-$a
  MAKEFLAGS=-j2 mise exec -- script/census setup --rails rails/rails@50c54eed06 --ruby ~/w/r-master \
    --ruby-overlays ~/w/overlays --apps $a --corpus census5 > ~/w/logs/setup-$a.log 2>&1
  echo "$(date +%T) setup $a rc=$?" >> $log
done
until grep -q "build done" ~/w/logs/build.log 2>/dev/null; do sleep 30; done
g=lib/ruby/gems/4.1.0+6
for v in old new mg; do
  [ -L ~/w/r-$v/$g ] || { rm -rf ~/w/r-$v/$g && ln -s ~/w/r-master/$g ~/w/r-$v/$g; }
done
for v in master m760; do
  (cd ~/w/ruby-bench/benchmarks/shipit && env -u RUBYOPT PATH=$HOME/w/r-$v/bin:$PATH MAKEFLAGS=-j2 bundle install \
    > ~/w/logs/shipit-bundle-$v.log 2>&1)
  echo "$(date +%T) shipit bundle $v rc=$?" >> $log
done
for v in master old new m760; do
  d=~/w/gcmajors/$v; mkdir -p $d && cp fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-24/gcmajors/* $d/
  (cd $d && ~/w/r-$v/bin/ruby extconf.rb > build.log 2>&1 && make >> build.log 2>&1)
  echo "$(date +%T) gcmajors $v rc=$?" >> $log
done
echo "$(date +%T) setup done" >> $log
exec sleep infinity
