#!/usr/bin/env bash
# Census 12 corpus: census 11's 8 apps, set up on Rails main 088fc0cf61.
cd /home/user/workspace/repo
export PATH=$HOME/.local/bin:$PATH
for app in ${APPS:-blog writebook codetriage pingcrm redprints-cfp react-starter-kit casa hackatime}; do
  echo "== $app $(date -u +%T)"
  mise exec ruby@4.0.9 -- script/census setup --rails 088fc0cf61e4ba0c7987decafacc69adb3e22eec --apps $app
  echo "exit $? $(date -u +%T)"
done
echo SETUPDONE
sleep infinity
