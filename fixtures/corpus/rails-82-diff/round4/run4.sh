#!/bin/bash
# run4.sh TAG WRITER_ENC READER_ENC: both trees write under WRITER_ENC, then each tree reads both under READER_ENC.
. ~/src/diff/env.sh; unset BUNDLE_WITHOUT
cd ~/src/xv
B=$PWD/b4; TAG=$1; WE=$2; RE=$3
for t in 81 main; do XV_ENC=$WE XV_TREE=$t BUNDLE_GEMFILE=$PWD/$t/Gemfile bundle exec ruby xv4.rb write $B 2>&1 | grep -v '^\s*from\|DEPRECATION' | head -3; done
mkdir -p out4/$TAG
for r in 81 main; do for s in 81 main; do XV_ENC=$RE XV_TREE=$r BUNDLE_GEMFILE=$PWD/$r/Gemfile bundle exec ruby xv4.rb read $B $s-enc_$WE out4/$TAG/$r-from-$s.tsv 2>&1 | grep -v '^\s*from\|DEPRECATION' | head -3; done; done
wc -l out4/$TAG/*.tsv | tail -1
