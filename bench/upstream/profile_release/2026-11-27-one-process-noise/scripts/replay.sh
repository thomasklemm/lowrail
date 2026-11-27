#!/usr/bin/env bash
# replay.sh [OUT]: gate.rb over this record's captures (captures.tar.xz) and the census field test's one-process
# captures (census-field-test/apps/*/reports.tar.xz), with compare before (16b53491) and after this change (HEAD).
# Run from the Lowrail checkout; writes the report to OUT (default results.txt beside this directory's README).
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
out=${1:-$here/results.txt}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/before" "$work/caps" "$work/ft"
git -C "$root" archive 16b53491 gem/lib | tar -x -C "$work/before"
tar -xJf "$here/captures.tar.xz" -C "$work/caps"
P='output_safety|erb/util'
# Wall-clock rows on Hackatime (README, Causes): left out only in the IGNORE lines.
T='addressable/uri.rb:424|PullRepoCommitsJob#perform|My::ProjectRepoMappingsController#index'
gate() { ruby -I"$1" "$here/scripts/gate.rb" "${@:2}" | sed -n '/^unchanged/p;/^planted/p;/false alarms/p;/plant caught/p'; }
both() { # title, gate arguments
  local title=$1; shift
  for lib in before after; do
    local dir=$work/before/gem/lib
    [ $lib = after ] && dir=$root/gem/lib
    echo "== $title, compare $lib"
    gate "$dir" "$@"
  done
}
c=$work/caps
{
  both "Hackatime, gem 16b53491 (h2-h6, d1)" x $c/hackatime/{h2,h3,h4,h5,h6,d1}
  both "Hackatime, this change's counter, wrapper fe85e96a then 15ee2407 (g1-g6; gp1, gp2 planted)" "$P|LeaderboardsController#index" \
    $c/hackatime/g{1..6} -- $c/hackatime/gp1 $c/hackatime/gp2
  both "Hackatime, intermediate gem that left out socket.rb by file (n1-n9; np1, np2 planted)" "$P|LeaderboardsController#index" \
    $c/hackatime/n{1..9} -- $c/hackatime/np1 $c/hackatime/np2
  for set in "h2 h3 h4 h5 h6 d1" "g1 g2 g3 g4 g5 g6" "n1 n2 n3 n4 n5 n6 n7 n8 n9"; do
    echo "== Hackatime ($set), compare before, wall-clock rows left out"
    IGNORE=$T gate "$work/before/gem/lib" x $(for n in $set; do echo $c/hackatime/$n; done)
  done
  both "CASA, db:test:prepare before each capture (r1-r6; rp1 planted)" "$P|CasaCasesController#index" \
    $c/casa/r{1..6} -- $c/casa/rp1
  both "CASA, CI=1 and db:test:prepare (ci1-ci4; cip1 planted)" "$P|CasaCasesController#index" \
    $c/casa/ci{1..4} -- $c/casa/cip1
  for app in casa hackatime-serial writebook-w4 writebook-serial; do
    mkdir -p "$work/ft/$app"
    tar -xJf "$root/bench/upstream/profile_release/census-field-test/apps/$app/reports.tar.xz" -C "$work/ft/$app"
    caps=$(ls -d "$work/ft/$app"/u[0-9] | sort -V)
    planted=$(ls -d "$work/ft/$app"/planted "$work/ft/$app"/planted2 2>/dev/null || true)
    re=$P
    case $app in
      casa) re="$P|CasaCasesController#index" ;;
      hackatime-serial) re="$P|LeaderboardsController#index" ;;
      writebook-serial) re="$P|SessionsController#create" ;;
    esac
    both "Field test $app (recorded)" "$re" $caps -- $planted
  done
} > "$out" 2>&1
echo "wrote $out"
