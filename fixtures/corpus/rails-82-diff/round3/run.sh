#!/bin/bash
# run.sh TAG "WRITER_ENV_81" "WRITER_ENV_MAIN" "READER_ENV_81" "READER_ENV_MAIN"
# Each tree writes under its writer env; each tree then reads both trees' data under its reader env.
. ~/src/diff/env.sh; unset BUNDLE_WITHOUT
cd ~/src/xv
B=$PWD/base
TAG="$1"; declare -A W=([81]="$2" [main]="$3"); declare -A RD=([81]="$4" [main]="$5")
srcname() { env $1 ruby -e 'puts [ENV["XV_COOKIE_SER"]||"json",ENV["XV_SESSION"]||"cookie",ENV["XV_DEFAULTS"]||"8.1",ENV["XV_SKB_MODE"]||"same",ENV["XV_CBC"] ? "cbc":"gcm"].join("-")'; }
for t in 81 main; do env X=1 ${W[$t]} XV_TREE=$t BUNDLE_GEMFILE=$PWD/$t/Gemfile bundle exec ruby xv.rb write $B 2>&1 | grep -v '^\s*from' | grep -v '^secret' | head -3; done
mkdir -p out/$TAG
for r in 81 main; do for s in 81 main; do env X=1 ${RD[$r]} XV_TREE=$r BUNDLE_GEMFILE=$PWD/$r/Gemfile bundle exec ruby xv.rb read $B $s-$(srcname "X=1 ${W[$s]}") out/$TAG/$r-from-$s.tsv 2>&1 | grep -v '^\s*from' | head -3; done; done
wc -l out/$TAG/*.tsv | tail -1
