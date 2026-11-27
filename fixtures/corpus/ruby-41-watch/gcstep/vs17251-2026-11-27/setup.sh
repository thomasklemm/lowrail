#!/bin/bash
# setup.sh: as vs17251-2026-11-24/setup5.sh. census5 Blog/Fizzy/Lobsters on Rails main 50c54eed06 with ~/w/r-base and
# the same Ruby overlays (frontier-master + round 2's Fizzy uuid patch and Lobsters typedstore initializer), then the
# shipit bundle. head and base2 share base's gem dir (same revision, head differs only in gc/default/default.c).
# Log ~/w/logs/setup.log.
cd /home/user/workspace/repo
log=~/w/logs/setup.log
F=fixtures/corpus/frontier-master R=fixtures/corpus/ruby-master-round-2
mkdir -p ~/w/overlays && cp $F/blog.patch ~/w/overlays/
cat $F/fizzy.patch $R/fizzy-rails-main-uuid.patch > ~/w/overlays/fizzy.patch
{ cat $F/lobsters.patch; f=config/initializers/census_typedstore_rails_main.rb
  printf 'diff --git a/%s b/%s\nnew file mode 100644\n--- /dev/null\n+++ b/%s\n@@ -0,0 +1,%d @@\n' $f $f $f $(wc -l < $R/${f##*/})
  sed 's/^/+/' $R/${f##*/}; } > ~/w/overlays/lobsters.patch
until grep -q "build done" ~/w/logs/build.log 2>/dev/null; do sleep 30; done
# One app copy per mode (census5 interp, census5y YJIT, census5z ZJIT), so the three mode lanes never share a database.
for c in census5 census5y census5z; do
  for a in blog fizzy lobsters; do
    [ -f .corpus/$c-$a/.census.json ] && continue
    rm -rf .corpus/$c-$a
    MAKEFLAGS=-j8 mise exec -- script/census setup --rails rails/rails@50c54eed06 --ruby ~/w/r-base \
      --ruby-overlays ~/w/overlays --apps $a --corpus $c > ~/w/logs/setup-$c-$a.log 2>&1
    echo "$(date +%T) setup $c $a rc=$?" >> $log
  done
done
g=$(cd ~/w/r-base && ls -d lib/ruby/gems/*)
for v in head base2; do
  [ -L ~/w/r-$v/$g ] || { rm -rf ~/w/r-$v/$g && ln -s ~/w/r-base/$g ~/w/r-$v/$g; }
done
(cd ~/w/ruby-bench/benchmarks/shipit && env -u RUBYOPT PATH=$HOME/w/r-base/bin:$PATH MAKEFLAGS=-j8 bundle install \
  > ~/w/logs/shipit-bundle.log 2>&1)
echo "$(date +%T) shipit bundle rc=$?" >> $log
echo "$(date +%T) setup done" >> $log
