#!/usr/bin/env bash
# Discourse's ERB::Util patch against Rails 8.1 and main around rails/rails#59570 (VM1 side finding).
#   run.sh RAILS_CLONE DISCOURSE_CLONE OUT_DIR   (Ruby 4.0.9 on PATH; gems: actionpack/actionview deps, benchmark-ips)
# Trees: 8-1-stable 71e963ed1b, main before #59570 13b5592657 (bdb3d96^1), main 50c54eed06, a second main
# checkout for A/A, and main plus c_memo.patch / c_exact.patch (option c prototypes). Discourse 9daeae2a74.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
rails=$1 discourse=$2 out=$3
mkdir -p "$out"
tree() {
  [ -d "$out/$1" ] && return
  git -C "$rails" worktree add -q --detach "$out/$1" "$2"
  [ -z "${3:-}" ] || git -C "$out/$1" apply "$here/$3"
}
tree r81 71e963ed1b; tree rpre 13b5592657; tree rmain 50c54eed06; tree rmain2 50c54eed06
tree rcmemo 50c54eed06 c_memo.patch; tree rcexact 50c54eed06 c_exact.patch
patch=$out/discourse_erb_util.rb
git -C "$discourse" show 9daeae2a74:lib/freedom_patches/erb_util.rb > "$patch"

for t in r81 rpre rmain rcmemo; do
  for p in "" "$patch" "$patch $here/discourse_output_buffer_sketch.rb"; do
    echo "== $t ${p:+$(basename -a $p | tr '\n' ' ')}"
    RUBYOPT=-W0 ruby "$here/repro.rb" "$out/$t" $p
  done
done > "$out/repro.txt"

for mode in interp yjit; do
  for t in rmain rmain2 rpre rcmemo rcexact; do echo "$mode $t $("$here/ir_append.sh" ruby $mode "$out/$t" 2000)"; done
  for t in rpre rcmemo rcexact; do echo "$mode $t+discourse $("$here/ir_append.sh" ruby $mode "$out/$t" 2000 "$patch")"; done
done > "$out/ir.txt"

trees="main=$out/rmain main2=$out/rmain2 pre=$out/rpre cmemo=$out/rcmemo cexact=$out/rcexact"
SCRIPT=$here/ips_append.rb CORE=${CORE:-1} bash "$here/../tag/ips_matrix.sh" "$out/ips_yjit.txt" yjit 5 $trees
SCRIPT=$here/ips_append.rb CORE=${CORE:-1} bash "$here/../tag/ips_matrix.sh" "$out/ips_interp.txt" interp 5 $trees
