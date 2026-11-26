#!/usr/bin/env bash
# run-a.sh : the first review's reproductions against the gem built from 7a5ee0b6 (installed in both Rubies).
S=/home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-review-fable/scripts
C=/home/user/workspace/repo/.amp/in/orb-backup/confirm
L=/tmp/pr2/logs
bash $C/rspec-extra.sh /tmp/pr/a72/rspec 3.3.14 > $L/rspec-extra.txt 2>&1
PATTERN='^  +[^ ]' VARIANTS="noseed seed99" bash $S/probes/t4.sh /tmp/pr/a72/rspec /tmp/pr2/t4-rspec 3.3.14 -- rspec -f d > $L/t4-rspec72.log 2>&1
VARIANTS="noseed seed99 par2" bash $S/probes/t4.sh /tmp/pr/a81/fresh /tmp/pr2/t4-fresh 4.0.7 -- bin/rails test -v > $L/t4-fresh81.log 2>&1
bash $S/t8.sh /tmp/pr/a81/fresh 4.0.7 > $L/t8.log 2>&1
bash $S/misc.sh /tmp/pr/a81/fresh /tmp/pr/a72/rspec "$(. $S/env.sh 4.0.7; gem contents lowrail-profile | grep exe/lowrail-profile)" > $L/misc.txt 2>&1
bash $S/t7.sh /tmp/pr/a81/t1 4.0.7 > $L/t7-out.txt 2>&1
echo done > $L/run-a.done
