#!/usr/bin/env bash
# run-g.sh : the final head 0ee4aed2. Its gem installed in both Rubies, the --timeout probes again (the exe's wait
# for the group is what changed since 53a071fd), the suites, and the mutants of the exe's --timeout branch.
S=/home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-review-fable/scripts
C=/home/user/workspace/repo/.amp/in/orb-backup/confirm
L=/tmp/pr2/logs
while pgrep -f "confirm/mutants.rb" > /dev/null; do sleep 3; done
for r in 4.0.7 3.3.14; do ( . $C/../env.sh $r; gem uninstall lowrail-profile -x -a --force >/dev/null 2>&1; gem install --local --no-document /tmp/pr2/build4/lowrail-profile-0.1.0.rc1.gem 2>&1 | tail -1
  d=$(gem contents lowrail-profile | grep exe/lowrail-profile | sed 's#/exe/lowrail-profile##'); cmp $d/exe/lowrail-profile /tmp/pr2/final2/gem/exe/lowrail-profile && diff -rq $d/lib /tmp/pr2/final2/gem/lib | grep -v "Only in /tmp" ; echo "$r: the installed exe is 0ee4aed2's" ); done > $L/install-0ee4aed2.txt 2>&1
(. $C/../env.sh 4.0.7; ruby $C/ps-probe.rb /tmp/pr2/final2/gem/exe/lowrail-profile) > $L/ps-probe-0ee4aed2.txt 2>&1
(. $C/../env.sh 4.0.7; ruby $C/trap-restore.rb /tmp/pr2/final2/gem/exe/lowrail-profile) > $L/trap-restore-0ee4aed2.txt 2>&1
bash $S/t8.sh /tmp/pr/a81/fresh 4.0.7 > $L/t8-0ee4aed2.log 2>&1
bash $C/suite.sh 4.0.7 /tmp/pr2/final2/gem $L/suite-40-0ee4aed2.log
bash $C/suite.sh 3.3.14 /tmp/pr2/final2/gem $L/suite-33-0ee4aed2.log
git -C /tmp/pr2/mut checkout -q --detach 0ee4aed2
(. $C/../env.sh 4.0.7; ruby $C/mutants.rb 4.0.7 'timeout|ps |glob|gem inside|BUNDLER') > $L/mutants-0ee4aed2.txt 2>&1
# smallest-fixes.patch applied in a worktree at 0ee4aed2 (a test reads ../bench, so not in a copy of gem/).
git worktree add --detach /tmp/pr2/fixwt 0ee4aed2 && git -C /tmp/pr2/fixwt apply /tmp/pr2/smallest-fixes.patch
bash $C/suite.sh 4.0.7 /tmp/pr2/fixwt/gem $L/suite-40-fixed.log
bash $C/suite.sh 3.3.14 /tmp/pr2/fixwt/gem $L/suite-33-fixed.log
echo done > $L/run-g.done
