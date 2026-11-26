#!/usr/bin/env bash
C=/home/user/workspace/repo/.amp/in/orb-backup/confirm; S=/home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-review-fable/scripts; L=/tmp/pr2/logs
while [ ! -f $L/run-b.done ]; do sleep 5; done
(. $C/../env.sh 4.0.7; ruby $C/trap-restore.rb /tmp/pr2/wt/gem/exe/lowrail-profile) > $L/trap-restore.txt 2>&1
(. $C/../env.sh 4.0.7; sed '/^    traps.each { |signal, handler| trap(signal, handler) }$/d' /tmp/pr2/wt/gem/exe/lowrail-profile > /tmp/pr2/norestore-exe; mkdir -p /tmp/pr2/norestore/exe; mv /tmp/pr2/norestore-exe /tmp/pr2/norestore/exe/lowrail-profile; ln -sfn /tmp/pr2/wt/gem/lib /tmp/pr2/norestore/lib; ln -sfn /tmp/pr2/wt/gem/ext /tmp/pr2/norestore/ext; echo "without the line that restores the traps:"; ruby $C/trap-restore.rb /tmp/pr2/norestore/exe/lowrail-profile) >> $L/trap-restore.txt 2>&1
(. $C/../env.sh 4.0.7; echo "5cdc5669 against its parent 1618fc38, the T1 app's kept runs:"; ruby $C/stream-equal.rb /tmp/pr2/old/gem/lib /tmp/pr2/stream/gem/lib /tmp/pr/a81/t1/tmp/lp-t1c
  cd /tmp/pr/a81/fresh; PARALLEL_WORKERS=2 bundle exec lowrail-profile --keep-runs --out tmp/lp-keep2 -- bin/rails test > /dev/null 2>&1
  echo "1618fc38 against 60387485, the fresh app's kept runs (two workers, no gem inside the root):"; ruby $C/stream-equal.rb /tmp/pr2/old/gem/lib /tmp/pr2/wt/gem/lib /tmp/pr/a81/fresh/tmp/lp-keep2; rm -rf tmp/lp-keep2) > $L/stream-equal.txt 2>&1
(
  . $C/../env.sh 4.0.7; gem spec /tmp/pr2/build2/lowrail-profile-0.1.0.rc1.gem --ruby > /tmp/pr2/unpacked/lowrail-profile-0.1.0.rc1/lowrail-profile.gemspec
  cd /tmp/pr/a81/t1v; rm -rf tmp/lowrail-profile
  bundle install > /tmp/pr2/t1v-bundle.log 2>&1; echo "bundle install: exit $?"
  PARALLEL_WORKERS=1 bundle exec lowrail-profile --keep-runs --top 400 -- bin/rails test test/controllers test/integration/many_test.rb > /tmp/pr2/t1v-run.log 2>&1; echo "exit $?"
  grep -n "Not attributed" tmp/lowrail-profile/report.md | cut -c1-400
  ruby $S/t1-report.rb tmp/lowrail-profile/report.json | grep -v "^groups\|^controller"
  ruby -rjson -e 'r=JSON.parse(File.read("tmp/lowrail-profile/report.json")); puts r["groups"].map { _1["group"] }.sort.join(", "); puts r["ranked"].map { _1["site"] }.grep_v(/\A(RAILS|GEM|RUBY)\//).first(5).inspect; puts r["app_lines"].map { _1["line"] }.grep(/vendor|gems/).inspect'
) > $L/t1v.txt 2>&1
bash $C/m523.sh 4.0.7 > $L/m523.txt 2>&1
echo done > $L/run-c.done
