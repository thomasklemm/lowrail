#!/usr/bin/env bash
L=/tmp/pr2/logs
while [ ! -f $L/run-d.done ]; do sleep 5; done
bash /home/user/workspace/repo/.amp/in/orb-backup/confirm/m523.sh > $L/m523.txt 2>&1
echo done > $L/run-e.done
