#!/usr/bin/env bash
# serial.sh GEM: the fresh app and Campfire, the two corpus apps that profile in several processes, captured again
# with PARALLEL_WORKERS=1 (one process), now that compare refuses captures of parallel workers.
set -u
here=$(cd "$(dirname "$0")" && pwd); out=$(cd "$here/.." && pwd); repo=$(cd "$here/../../../../.." && pwd)
final=$repo/bench/upstream/profile_release/2026-11-25-final/scripts m4=$repo/bench/upstream/profile_release/2026-11-25/scripts gem=$1
export PARALLEL_WORKERS=1
case ${2:-all} in
  fresh|all)
    GEM_HOME=$HOME/fresh/gems40 GEM_PATH=$HOME/fresh/gems40 PATH="$(~/.local/bin/mise where ruby@4.0.7)/bin:$PATH" \
      gem install --local --no-document "$gem" > /dev/null
    "$final/fresh_captures.sh" "$repo/.corpus/fresh-81" "$HOME/fresh/gems40" "$out/fresh-81" s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 s12 ;;&
  campfire|all)
    rm -f "$repo/.corpus/rc-campfire"/Gemfile.lowrail*
    PLANT='app/controllers/rooms_controller.rb:11a\    20.times { ERB::Util.html_escape("a<b") }' \
      "$m4/proof.sh" "$repo/.corpus/rc-campfire" "$out/campfire" "$gem" s1,s2,s3,s4,planted,planted2 -- bin/rails test -v ;;
esac
echo ALL DONE
