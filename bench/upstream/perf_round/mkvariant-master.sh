#!/bin/bash
# mkvariant-master.sh NAME   Gemfile.NAME-r41 per benchmark, bundled with Ruby master (gems under ~/ruby-master), Rails tree ~/src/wt/NAME
v=$1
export PATH=$HOME/ruby-master/bin:$HOME/.cargo/bin:$PATH
cd ~/src/ruby-bench/benchmarks
for b in ${BENCHES:-railsbench erubi-rails lobsters shipit}; do
  printf 'ENV["RAILS_PATH"] = "/home/user/src/wt/%s"\neval_gemfile File.join(__dir__, "Gemfile.rails")\n' $v > $b/Gemfile.$v-r41
  if [ "$v" != m ] && [ -f $b/Gemfile.m-r41.lock ]; then
    sed "s#/wt/m\$#/wt/$v#;s#/wt/m/#/wt/$v/#g" $b/Gemfile.m-r41.lock > $b/Gemfile.$v-r41.lock
  elif [ ! -f $b/Gemfile.$v-r41.lock ]; then
    cp $b/Gemfile.m.lock $b/Gemfile.$v-r41.lock
  fi
  (cd $b && BUNDLE_GEMFILE=$PWD/Gemfile.$v-r41 bundle install --quiet) || echo "BUNDLE FAILED $b $v"
done
echo "variant $v-r41 done"
