#!/usr/bin/env bash
# run-h.sh : the delta 0ee4aed2..644c99e4. Its gem installed in both Rubies; both must-fixes on the apps; the exe's
# wait for the stopped group again (ps now runs through IO.popen); the two OSM option sets; suites; mutants.
S=/home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-review-fable/scripts
C=/home/user/workspace/repo/.amp/in/orb-backup/confirm
L=/tmp/pr2/dlogs; mkdir -p $L
for r in 4.0.7 3.3.14; do ( . $C/../env.sh $r; gem uninstall lowrail-profile -x -a --force >/dev/null 2>&1; gem install --local --no-document /tmp/pr2/build5/lowrail-profile-0.1.0.rc1.gem 2>&1 | tail -1
  d=$(gem contents lowrail-profile | grep exe/lowrail-profile | sed 's#/exe/lowrail-profile##'); cmp $d/exe/lowrail-profile /tmp/pr2/delta/gem/exe/lowrail-profile && cmp $d/lib/lowrail/profile_report.rb /tmp/pr2/delta/gem/lib/lowrail/profile_report.rb && cmp $d/README-profile.md /tmp/pr2/delta/gem/README-profile.md && echo "$r: the installed exe, report and README are 644c99e4's" ); done > $L/install.txt 2>&1
bash $C/gems-app.sh 4.0.7 > $L/gems-app.txt 2>&1
(. $C/../env.sh 4.0.7; echo "0ee4aed2:"; ruby $C/gems-dir.rb /tmp/pr2/final2/gem/lib; echo "644c99e4:"; ruby $C/gems-dir.rb /tmp/pr2/delta/gem/lib) > $L/gems-dir.txt 2>&1
(
  . $C/../env.sh 4.0.7; cd /tmp/pr/a81/t1
  PARALLEL_WORKERS=1 bundle exec lowrail-profile --keep-runs --top 400 --out tmp/lp-t1d -- bin/rails test test/controllers test/integration/many_test.rb > /tmp/pr2/t1d-run.log 2>&1; echo "exit $?"
  grep -n "Not attributed" tmp/lp-t1d/report.md | cut -c1-300
  ruby $S/t1-report.rb tmp/lp-t1d/report.json | grep -v "^groups\|^controller" | cut -c1-330
  git status --porcelain | head -5
) > $L/t1.txt 2>&1
(. $C/../env.sh 4.0.7
  echo "0ee4aed2 against 644c99e4, the path-gem app's kept runs:"; ruby $C/stream-equal.rb /tmp/pr2/final2/gem/lib /tmp/pr2/delta/gem/lib /tmp/pr/a81/t1/tmp/lp-t1d
  cd /tmp/pr/a81/fresh; PARALLEL_WORKERS=2 bundle exec lowrail-profile --keep-runs --out tmp/lp-keep2 -- bin/rails test > /dev/null 2>&1
  echo "0ee4aed2 against 644c99e4, the fresh app's kept runs (two workers):"; ruby $C/stream-equal.rb /tmp/pr2/final2/gem/lib /tmp/pr2/delta/gem/lib /tmp/pr/a81/fresh/tmp/lp-keep2; rm -rf tmp/lp-keep2) > $L/report-equal.txt 2>&1
(. $C/../env.sh 4.0.7; ruby $C/ps-probe.rb /tmp/pr2/delta/gem/exe/lowrail-profile
  d=$(mktemp -d); mkdir $d/bin; printf '#!/bin/sh\necho "ps: no /proc" >&2\nexit 1\n' > $d/bin/ps; chmod +x $d/bin/ps
  (cd $d && PATH="$d/bin:$PATH" ruby /tmp/pr2/delta/gem/exe/lowrail-profile --timeout 1 --runs 1 --out o -- ruby -e 'trap("TERM") { sleep 3; exit 0 }; sleep' > /dev/null 2> err.txt; echo "a ps that prints 'ps: no /proc' on stderr and exits 1: exit $?; such lines on lowrail-profile's stderr: $(grep -c 'ps: no /proc' err.txt)"); rm -rf $d) > $L/ps-probe.txt 2>&1
(. $C/../env.sh 4.0.7; ruby $C/trap-restore.rb /tmp/pr2/delta/gem/exe/lowrail-profile) > $L/trap-restore.txt 2>&1
bash $S/t8.sh /tmp/pr/a81/fresh 4.0.7 > $L/t8.log 2>&1
( cd /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-t3; for s in osm-serial osm-parallel; do /usr/bin/time -f "$s %es" bash scripts/run_options.sh $s; done; echo "git status of the receipts:"; git status --short . ; echo "replay done" ) > $L/replay.txt 2>&1
bash $C/suite.sh 4.0.7 /tmp/pr2/delta/gem $L/suite-40.log
bash $C/suite.sh 3.3.14 /tmp/pr2/delta/gem $L/suite-33.log
git -C /home/user/workspace/repo worktree add --detach /tmp/pr2/mutd 644c99e4 > /dev/null 2>&1
(. $C/../env.sh 4.0.7; ruby $C/mutants-delta.rb 4.0.7) > $L/mutants.txt 2>&1
echo done > $L/run-h.done
