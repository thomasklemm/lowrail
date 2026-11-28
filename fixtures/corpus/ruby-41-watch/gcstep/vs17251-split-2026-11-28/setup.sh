#!/bin/bash
# setup.sh: as vs17251-2026-11-27/setup.sh, but one app copy per app (corpus census5, one sequential lane): Blog,
# Fizzy, Lobsters on Rails main 50c54eed06 with ~/w/r-base and the same overlays; then the other builds share base's
# gem dir (same revision; they differ only in gc/default/default.c); then the gcmajors extension per build, the split
# harness in ruby-bench, and every ruby-bench benchmark's bundle. Log ~/w/logs/setup.log.
cd /home/user/workspace/repo
fx=fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28
log=~/w/logs/setup.log
F=fixtures/corpus/frontier-master R=fixtures/corpus/ruby-master-round-2
mkdir -p ~/w/overlays && cp $F/blog.patch ~/w/overlays/
cat $F/fizzy.patch $R/fizzy-rails-main-uuid.patch > ~/w/overlays/fizzy.patch
{ cat $F/lobsters.patch; f=config/initializers/census_typedstore_rails_main.rb
  printf 'diff --git a/%s b/%s\nnew file mode 100644\n--- /dev/null\n+++ b/%s\n@@ -0,0 +1,%d @@\n' $f $f $f $(wc -l < $R/${f##*/})
  sed 's/^/+/' $R/${f##*/}; } > ~/w/overlays/lobsters.patch
until grep -q "build done" ~/w/logs/build.log 2>/dev/null; do sleep 30; done
g=$(cd ~/w/r-base && ls -d lib/ruby/gems/*)
for v in base2 c1 head nocad; do
  [ -L ~/w/r-$v/$g ] || { rm -rf ~/w/r-$v/$g && ln -s ~/w/r-base/$g ~/w/r-$v/$g; }
done
for a in blog fizzy lobsters; do
  [ -f .corpus/census5-$a/.census.json ] && continue
  rm -rf .corpus/census5-$a
  MAKEFLAGS=-j16 mise exec -- script/census setup --rails rails/rails@50c54eed06 --ruby ~/w/r-base \
    --ruby-overlays ~/w/overlays --apps $a --corpus census5 > ~/w/logs/setup-$a.log 2>&1
  echo "$(date +%T) setup $a rc=$?" >> $log
done
for v in base base2 c1 head nocad; do
  rm -rf ~/w/gcmajors/$v && mkdir -p ~/w/gcmajors/$v && cp $fx/gcmajors/* ~/w/gcmajors/$v/
  (cd ~/w/gcmajors/$v && ~/w/r-$v/bin/ruby extconf.rb && make) > ~/w/logs/gcmajors-$v.log 2>&1
  echo "$(date +%T) gcmajors $v rc=$?" >> $log
done
cp $fx/harness.rb ~/w/ruby-bench/harness/split.rb
cp $fx/gcstep-harness.rb ~/w/ruby-bench/harness/gcstep.rb
for b in activerecord hexapdf liquid-c liquid-compile liquid-render lobsters mail railsbench sequel shipit ruby-lsp \
    erubi-rails chunky-png liquid-il psych-load rubocop; do
  [ -f ~/w/ruby-bench/benchmarks/$b/Gemfile ] || continue
  (cd ~/w/ruby-bench/benchmarks/$b && env -u RUBYOPT PATH=$HOME/w/r-base/bin:$PATH MAKEFLAGS=-j16 bundle install \
    > ~/w/logs/bundle-$b.log 2>&1)
  echo "$(date +%T) bundle $b rc=$?" >> $log
done
echo "$(date +%T) setup done" >> $log
