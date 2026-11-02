#!/bin/bash
# Census-3 patched rerun: apply Rails patches to the bundled e77813d4e8 checkout used by
# the .corpus/census3-* apps, profile all apps/modes, then restore the pristine copy.
# Usage: census_3_patched.sh LABEL PATCH...   (needs /tmp/w/rails-bundled-orig and census_3_profile.sh)
set -e
label=$1; shift
B=/home/user/.local/share/mise/installs/ruby/4.0.7/lib/ruby/gems/4.0.0/bundler/gems/rails-e77813d4e8d7
out=/home/user/workspace/repo/.lowrail/private/rails-main-census-3/after-$label
rm -rf $out; mkdir -p $out
for p in "$@"; do patch -s -p1 -d $B -i $p; done
trap 'rm -rf $B && cp -a /tmp/w/rails-bundled-orig $B' EXIT
for n in blog campfire fizzy writebook; do for m in interpreter yjit; do $(dirname $0)/census_3_profile.sh $n $m $out > /tmp/w/after-$label-$n-$m.log 2>&1 & done; done
wait
diff -r /tmp/w/rails-bundled-orig $B > /dev/null && echo "UNEXPECTED: patch not applied" || echo "patched run complete"
