#!/usr/bin/env bash
# Census 10 corpus: the 8 census 9 apps on main 4500a94c34.
cd /home/user/workspace/repo
for app in ${APPS:-blog writebook codetriage pingcrm redprints-cfp react-starter-kit casa hackatime}; do
  echo "== $app $(date -u +%T)"
  mise exec ruby@4.0.9 -- script/census setup --rails 4500a94c34d7052b84f81f6d7fd44f5bb8af3fff --apps $app
  echo "exit $? $(date -u +%T)"
done
