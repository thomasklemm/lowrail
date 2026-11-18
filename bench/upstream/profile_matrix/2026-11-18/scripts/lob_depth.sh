#!/bin/bash
# Control: the YAML side from a worktree at the same directory depth as the repo, own Rails only.
while ! grep -q "^ctl exit" /tmp/rerun/lob.done; do sleep 10; done
cd /home/user/workspace/lowrail-base
mise exec ruby@4.0.7 -- script/census app ~/apps/lobsters --name lobsters-ymld --workloads /home/user/workspace/lowrail-base/fixtures/census-app/lobsters.yml --prepare /home/user/workspace/lowrail-base/fixtures/census-app/lobsters_prepare.rb --no-cpu > /tmp/rerun/lob-ymld.log 2>&1
echo "ymld exit $? $(date -u +%T)" >> /tmp/rerun/lob.done
