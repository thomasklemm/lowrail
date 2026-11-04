#!/bin/bash
export N=${N:-2000}
cd ~/src/xv
rm -rf base out; mkdir base
. ~/src/diff/env.sh; unset BUNDLE_WITHOUT
XV_TREE=81 BUNDLE_GEMFILE=$PWD/81/Gemfile bundle exec ruby xv.rb setup $PWD/base
./run.sh base "" "" "" ""
for s in hybrid marshal message_pack message_pack_allow_marshal; do ./run.sh cookie-$s "XV_COOKIE_SER=$s" "XV_COOKIE_SER=$s" "XV_COOKIE_SER=$s" "XV_COOKIE_SER=$s"; done
./run.sh session-cache "XV_SESSION=cache" "XV_SESSION=cache" "XV_SESSION=cache" "XV_SESSION=cache"
./run.sh session-cache-marshal "XV_SESSION=cache XV_COOKIE_SER=marshal" "XV_SESSION=cache XV_COOKIE_SER=marshal" "XV_SESSION=cache XV_COOKIE_SER=marshal" "XV_SESSION=cache XV_COOKIE_SER=marshal"
./run.sh cbc-to-gcm "XV_CBC=1" "XV_CBC=1" "" ""
./run.sh skb-rotation "XV_SKB_MODE=old" "XV_SKB_MODE=old" "XV_SKB_MODE=new" "XV_SKB_MODE=new"
./run.sh defaults82 "" "XV_DEFAULTS=8.2" "" "XV_DEFAULTS=8.2"
./run.sh defaults82-hybrid "XV_COOKIE_SER=hybrid" "XV_DEFAULTS=8.2 XV_COOKIE_SER=hybrid" "XV_COOKIE_SER=hybrid" "XV_DEFAULTS=8.2 XV_COOKIE_SER=hybrid"
echo ALLDONE
