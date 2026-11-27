#!/usr/bin/env bash
# suite.sh DIR LABEL: CI=spec bundle exec rake on each Ruby, clean and with cgi/util preloaded.
dir=$1; label=$2; out=/home/user/workspace/repo/.amp/in/orb-backup/rk3-module/suite; mkdir -p $out
cd $dir
for v in ${RUBIES:-2.7.3 3.0.7 3.1.7 3.2.9 3.3.9 3.4.6 4.0.9}; do
  if [ -d /opt/hostedtoolcache/Ruby/$v ]; then bin=/opt/hostedtoolcache/Ruby/$v/x64/bin; else bin=$HOME/.local/share/mise/installs/ruby/$v/bin; fi
  export PATH=$bin:/usr/bin:/bin
  export BUNDLE_GEMFILE=$dir/Gemfile BUNDLE_LOCKFILE=/tmp/Gemfile-$v.lock
  cp -n /tmp/Gemfile-$v.lock Gemfile.lock 2>/dev/null; rm -f Gemfile.lock
  CI=spec bundle install --quiet > $out/$label-$v-install.txt 2>&1
  for mode in clean util; do
    pre=""; [ $mode = util ] && pre="-rcgi/util"
    CI=spec RUBYOPT="$pre" bundle exec rake > $out/$label-$v-$mode.txt 2>&1
    echo "$label $v $mode exit $? | $(ruby -v | cut -c1-12) | $(grep -E '^[0-9]+ runs' $out/$label-$v-$mode.txt | sort -n | tail -1) | $(grep -c "All test files passed" $out/$label-$v-$mode.txt)"
  done
  rm -f Gemfile.lock
done
