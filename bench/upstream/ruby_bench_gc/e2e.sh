#!/usr/bin/env bash
set -x
export PATH=$HOME/rubies/base/bin:$PATH
cd ~/w/b1
Z="--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024"
./run_benchmarks.rb --harness=gc --pvalue --no-sudo railsbench lobsters shipit \
  -e "base::$HOME/rubies/base/bin/ruby $Z" -e "base2::$HOME/rubies/base/bin/ruby $Z" -e "patch::$HOME/rubies/patch/bin/ruby $Z" > ~/w/out/e2e.txt 2>&1
echo E2E_DONE
sleep infinity
