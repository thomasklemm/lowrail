#!/usr/bin/env bash
# fetch.sh: corpus copies for the census field test, in parallel, logs in /home/user/ft/fetch-*.log
cd /home/user/workspace/repo
for a in campfire lobsters codetriage writebook fizzy pingcrm redprints-cfp react-starter-kit casa; do
  script/corpus $a ft-$a > /home/user/ft/fetch-$a.log 2>&1 &
done
for a in hackatime sure mastodon loomio discourse; do
  script/corpus $a ft-$a --source-only > /home/user/ft/fetch-$a.log 2>&1 &
done
wait
echo FETCH DONE
