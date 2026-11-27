#!/usr/bin/env bash
# TO1 page objects (README, Page level): main twice (A/A) and the head, per app and mode.
set -euo pipefail
cd /home/user/workspace/repo
export PATH=$(~/.local/bin/mise where ruby@4.0.10)/bin:$PATH
out=bench/upstream/to1-open-2026-11-27/page/objects
only="GET article,GET books,GET casa case edit"
apps=blog,writebook,casa
main=rails/rails@2e299253f942ab94041cc6f210ac9d33884c210d
head=thomasklemm/rails@18fd3c4a07
for ruby in 4.0.10 master; do
  if [ $ruby = master ]; then r=$HOME/rubies/master-0d399335b7/bin; modes=zjit; else r=4.0.10; modes=interp,yjit; fi
  script/census run --label main-$ruby --aa --corpus censusto1 --rails $main --ruby $r --modes $modes --apps $apps --only "$only" --out $out
  script/census run --label to1-$ruby --corpus censusto1 --rails $head --ruby $r --modes $modes --apps $apps --only "$only" --out $out
done
echo objects-done
