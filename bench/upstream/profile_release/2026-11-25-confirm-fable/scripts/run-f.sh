#!/usr/bin/env bash
# run-f.sh : the final head 53a071fd. Its gem installed in both Rubies; the probes that touch what changed since
# 60387485 (the exe's wait for the stopped group), then the suites, then every mutant again.
S=/home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-review-fable/scripts
C=/home/user/workspace/repo/.amp/in/orb-backup/confirm
L=/tmp/pr2/logs
for r in 4.0.7 3.3.14; do ( . $C/../env.sh $r; gem uninstall lowrail-profile -x -a --force >/dev/null 2>&1; gem install --local --no-document /tmp/pr2/build3/lowrail-profile-0.1.0.rc1.gem 2>&1 | tail -1
  d=$(gem contents lowrail-profile | grep exe/lowrail-profile | sed 's#/exe/lowrail-profile##'); cmp $d/exe/lowrail-profile /tmp/pr2/final/gem/exe/lowrail-profile && diff -rq $d/lib/lowrail/profile_report.rb /tmp/pr2/final/gem/lib/lowrail/profile_report.rb && echo "$r: installed exe and report are 53a071fd's" ); done > $L/install-final.txt 2>&1
(. $C/../env.sh 4.0.7; ruby $C/ps-probe.rb /tmp/pr2/final/gem/exe/lowrail-profile) > $L/ps-probe.txt 2>&1
(. $C/../env.sh 4.0.7; ruby $C/trap-restore.rb /tmp/pr2/final/gem/exe/lowrail-profile) > $L/trap-restore-final.txt 2>&1
bash $S/t8.sh /tmp/pr/a81/fresh 4.0.7 > $L/t8-final.log 2>&1
( . $C/../env.sh 4.0.7; cd /tmp/pr/a81/fresh; rm -rf tmp/g
  PARALLEL_WORKERS=1 bundle exec lowrail-profile --keep-runs --out tmp/g/keep -- bin/rails test test/controllers > /dev/null 2>&1
  PARALLEL_WORKERS=1 bundle exec lowrail-profile --out 'tmp/g/{keep,x}' -- bin/rails test test/controllers > /dev/null 2>&1
  echo "--out 'tmp/g/{keep,x}': exit $?; tmp/g/keep: $(ls tmp/g/keep | tr '\n' ' '); tmp/g/{keep,x}: $(ls 'tmp/g/{keep,x}' | tr '\n' ' ')"; rm -rf tmp/g ) > $L/glob-final.txt 2>&1
bash $C/suite.sh 4.0.7 /tmp/pr2/final/gem $L/suite-40-final.log
bash $C/suite.sh 3.3.14 /tmp/pr2/final/gem $L/suite-33-final.log
git -C /tmp/pr2/mut checkout -q --detach 53a071fd
(. $C/../env.sh 4.0.7; ruby $C/mutants.rb 4.0.7) > $L/mutants-final.txt 2>&1
echo done > $L/run-f.done
