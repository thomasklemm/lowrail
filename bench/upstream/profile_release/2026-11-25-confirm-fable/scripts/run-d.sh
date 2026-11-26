#!/usr/bin/env bash
C=/home/user/workspace/repo/.amp/in/orb-backup/confirm; L=/tmp/pr2/logs
while [ ! -f $L/run-c.done ]; do sleep 5; done
bash $C/ci-job.sh 4.0.7 /tmp/pr2/wt/gem/README-profile.md > $L/ci-job.log 2>&1
echo done > $L/run-d.done
