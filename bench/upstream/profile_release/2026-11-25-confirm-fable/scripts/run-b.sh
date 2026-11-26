#!/usr/bin/env bash
# run-b.sh : with the gem built from 60387485 installed in both Rubies.
S=/home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-review-fable/scripts
C=/home/user/workspace/repo/.amp/in/orb-backup/confirm
L=/tmp/pr2/logs
(
  . $C/../env.sh 4.0.7; cd /tmp/pr/a81/t1
  PARALLEL_WORKERS=1 bundle exec lowrail-profile --keep-runs --top 400 --out tmp/lp-t1c -- bin/rails test test/controllers test/integration/many_test.rb > /tmp/pr2/t1-run.log 2>&1; echo "exit $?"
  grep -n "Not attributed" tmp/lp-t1c/report.md | cut -c1-400
  ruby $S/t1-report.rb tmp/lp-t1c/report.json
  git status --porcelain | head -5
) > $L/t1.txt 2>&1
(. $C/../env.sh 4.0.7; ruby $C/stream-equal.rb /tmp/pr2/old/gem/lib /tmp/pr2/wt/gem/lib /tmp/pr/a81/t1/tmp/lp-t1c) > $L/stream-equal.txt 2>&1
(
  . $C/../env.sh 4.0.7; cd /tmp/pr/a81/t1v; rm -rf tmp/lowrail-profile
  ruby -pi -e 'sub(%r{/tmp/pr/unpacked/}, "/tmp/pr2/unpacked/")' Gemfile; bundle install > /tmp/pr2/t1v-bundle.log 2>&1; echo "bundle install: exit $?"
  PARALLEL_WORKERS=1 bundle exec lowrail-profile --keep-runs --top 400 -- bin/rails test test/controllers test/integration/many_test.rb > /tmp/pr2/t1v-run.log 2>&1; echo "exit $?"
  grep -n "Not attributed" tmp/lowrail-profile/report.md | cut -c1-400
  ruby $S/t1-report.rb tmp/lowrail-profile/report.json | grep -v "^groups\|^controller"
  ruby -rjson -e 'r=JSON.parse(File.read("tmp/lowrail-profile/report.json")); puts r["groups"].map { _1["group"] }.sort.join(", "); puts r["ranked"].map { _1["site"] }.grep_v(/\A(RAILS|GEM|RUBY)\//).first(5).inspect; puts r["app_lines"].map { _1["line"] }.grep(/vendor|gems/).inspect'
) > $L/t1v.txt 2>&1
bash $C/gems-app.sh 4.0.7 > $L/gems-app.txt 2>&1
(. $C/../env.sh 4.0.7; ruby $C/trap-restore.rb /tmp/pr2/wt/gem/exe/lowrail-profile) > $L/trap-restore.txt 2>&1
(. $C/../env.sh 4.0.7; sed '/^    traps.each { |signal, handler| trap(signal, handler) }$/d' /tmp/pr2/wt/gem/exe/lowrail-profile > /tmp/pr2/wt/gem/exe/lowrail-profile-norestore; echo "without the line that restores the traps:"; ruby $C/trap-restore.rb /tmp/pr2/wt/gem/exe/lowrail-profile-norestore; rm /tmp/pr2/wt/gem/exe/lowrail-profile-norestore) >> $L/trap-restore.txt 2>&1
bash $C/rspec-extra.sh /tmp/pr/a72/rspec 3.3.14 > $L/rspec-extra-60387485.txt 2>&1
bash $C/ci-job.sh 4.0.7 /tmp/pr2/wt/gem/README-profile.md > $L/ci-job.log 2>&1
echo done > $L/run-b.done
