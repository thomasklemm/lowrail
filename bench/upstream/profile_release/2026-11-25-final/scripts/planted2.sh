#!/usr/bin/env bash
# planted2.sh GEM: a second planted capture of Campfire, CodeTriage and Lobsters (the M4 receipts have one each),
# with the M4 plant and command, through the M4 proof.sh, so the README's confirm step has a planted head2.
set -u
here=$(cd "$(dirname "$0")" && pwd); out=$(cd "$here/.." && pwd); repo=$(cd "$here/../../../../.." && pwd)
s=$repo/bench/upstream/profile_release/2026-11-25/scripts gem=$1
add='20.times { ERB::Util.html_escape("a<b") }'
for a in campfire codetriage lobsters; do rm -f "$repo/.corpus/rc-$a"/Gemfile.lowrail*; done
PLANT="app/controllers/pages_controller.rb:28a\\    $add" "$s/proof.sh" "$repo/.corpus/rc-codetriage" "$out/codetriage" "$gem" planted2 -- bin/rails test --verbose
PLANT="app/controllers/rooms_controller.rb:11a\\    $add" "$s/proof.sh" "$repo/.corpus/rc-campfire" "$out/campfire" "$gem" planted2 -- bin/rails test -v
PLANT="app/controllers/home_controller.rb:39a\\    $add" "$s/proof.sh" "$repo/.corpus/rc-lobsters" "$out/lobsters" "$gem" planted2 -- bundle exec rspec --seed 1234 --format documentation
echo ALL DONE
