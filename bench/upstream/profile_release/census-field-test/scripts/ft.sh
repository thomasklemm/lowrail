#!/usr/bin/env bash
# ft.sh APP [STEPS]: the README's flow on one census app from the built gem, through M4's proof.sh/controls.sh.
# apps/APP.sh sets APPDIR, CMD (array), PLANT (FILE:SED-EXPR) and the app's environment; optional PLANT_RE.
# Default steps: plain plain2 off, six unchanged captures u1..u6, planted planted2, seed99.
# Then: off-env control, per-run outcomes, load order, overhead, the README CI job (cijob.sh), gate.rb.
set -u
here=$(cd "$(dirname "$0")" && pwd); repo=/home/user/workspace/repo
m4=$repo/bench/upstream/profile_release/2026-11-25/scripts
app=$1
GEM=/home/user/ft/lowrail-profile-0.1.0.rc1.gem
PLANT_RE='output_safety|erb/util'
source "$here/apps/$app.sh"
steps=${2:-plain,plain2,off,u1,u2,u3,u4,u5,u6,planted,planted2,seed99}
out=/home/user/ft/out/$app; mkdir -p "$out"
echo "== $app start $(date -u +%FT%TZ) steps $steps" >> "$out/timeline.txt"
export PLANT
"$m4/proof.sh" "$APPDIR" "$out" "$GEM" "$steps" -- "${CMD[@]}"
echo "proof.sh exit $?" >> "$out/timeline.txt"
[ -f "$out/off-env.log" ] || "$m4/controls.sh" "$APPDIR" "$out" -- "${CMD[@]}"
"$here/post.sh" "$app"
echo "== $app done $(date -u +%FT%TZ)" >> "$out/timeline.txt"
