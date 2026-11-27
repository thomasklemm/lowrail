#!/usr/bin/env bash
set -eu
root=/home/user/workspace/repo/.amp/in/orb-backup/rk3-astra
for v in 2.7.3 3.0.7 3.1.7 3.2.9 3.3.9 3.4.6 4.0.9; do
  bin=/opt/hostedtoolcache/Ruby/$v/x64/bin
  [ -x "$bin/ruby" ] || bin=$HOME/.local/share/mise/installs/ruby/$v/bin
  export PATH=$bin:/usr/bin:/bin
  for tree in base rack; do
    (
      cd "$root/$tree"
      export CI=spec
      rm -f Gemfile.lock
      bundle install > "$root/results/$tree-$v-install.txt" 2>&1
      cp Gemfile.lock "$root/results/$tree-$v-Gemfile.lock"
      for mode in clean util; do
        export RUBYOPT=''
        [ "$mode" != util ] || export RUBYOPT=-rcgi/util
        set +e
        bundle exec rake > "$root/results/$tree-$v-$mode-suite.txt" 2>&1
        status=$?
        set -e
        echo "$tree $v $mode status=$status"
        grep -E '^[0-9]+ runs|All test files passed' "$root/results/$tree-$v-$mode-suite.txt" | head -1
        grep 'All test files passed' "$root/results/$tree-$v-$mode-suite.txt" || true
      done
    )
  done
done
