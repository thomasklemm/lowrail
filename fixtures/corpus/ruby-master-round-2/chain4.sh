#!/bin/bash
# After chain3: rerun #59141 main:yjit railsbench with the gate read right next to the window (11-14 16:05 fix).
cd /home/user/workspace/repo
until grep -q "chain3 done" ~/w/logs/r2q.log 2>/dev/null; do sleep 30; done
bash .amp/in/orb-backup/r59141_cg.sh
echo "$(date +%T) chain4 done" >> ~/w/logs/r2q.log
