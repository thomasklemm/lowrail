#!/bin/bash
# mkvariant.sh NAME [SHA]   worktree ~/src/wt/NAME (if SHA given and missing) and Gemfile.NAME + lock per benchmark.
# The first variant "m" is bundled from scratch; later ones copy m's lock with the path rewritten.
set -e
v=$1; sha=$2
export PATH=$(mise where ruby@4.0.9)/bin:$PATH
[ -n "$sha" ] && [ ! -d ~/src/wt/$v ] && git -C ~/src/rails worktree add -q --detach ~/src/wt/$v $sha
cd ~/src/ruby-bench/benchmarks
for b in ${BENCHES:-railsbench erubi-rails lobsters shipit}; do
  printf 'ENV["RAILS_PATH"] = "/home/user/src/wt/%s"\neval_gemfile File.join(__dir__, "Gemfile.rails")\n' $v > $b/Gemfile.$v
  if [ "$v" != m ] && [ -f $b/Gemfile.m.lock ]; then
    sed "s#/wt/m\$#/wt/$v#;s#/wt/m/#/wt/$v/#g" $b/Gemfile.m.lock > $b/Gemfile.$v.lock
  elif [ ! -f $b/Gemfile.$v.lock ]; then
    cp $b/Gemfile.lock $b/Gemfile.$v.lock
  fi
  (cd $b && BUNDLE_GEMFILE=$PWD/Gemfile.$v bundle install --quiet) || { echo "BUNDLE FAILED $b $v"; exit 1; }
done
echo "variant $v ok"
