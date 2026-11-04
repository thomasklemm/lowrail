#!/bin/bash
export N=${N:-1200}
cd ~/src/xv
rm -rf b4 out4; mkdir b4
. ~/src/diff/env.sh; unset BUNDLE_WITHOUT
redis-cli -p 6390 flushall >/dev/null; ruby -rsocket -e 's = TCPSocket.new("localhost", 11290); s.write("flush_all\r\n"); puts s.gets'
XV_TREE=81 BUNDLE_GEMFILE=$PWD/81/Gemfile bundle exec ruby xv4.rb setup $PWD/b4 >/dev/null 2>&1
./run4.sh base base base
./run4.sh key-rotation old rotated
./run4.sh unencrypted-to-encrypted plain unencrypted_ok
./run4.sh nondet-to-det nondet det_prev_nondet
./run4.sh attr-previous-key old attr_prev_key
./run4.sh rollback-to-old-keys base old
echo ALLDONE
