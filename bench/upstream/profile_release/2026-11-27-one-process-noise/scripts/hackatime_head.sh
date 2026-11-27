#!/usr/bin/env bash
# hk-capture.sh NAME...: one-process Hackatime captures with the checkout's lowrail-profile, runs kept, into ~/hk/NAME.
set -u
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.7/bin:$PATH
export TEST_DATABASE_URL=postgres://user@localhost/ft_hackatime_test PARALLEL_WORKERS=1
cd /home/user/workspace/repo/.corpus/ft-hackatime
mkdir -p ~/hk
for n in "$@"; do
  t0=$(date +%s)
  BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile --keep-runs --out ~/hk/$n -- bin/rails test -v > ~/hk/$n.log 2>&1
  echo "$n exit $? $(( $(date +%s) - t0 ))s at $(date -u +%T)" >> ~/hk/summary.txt
done
