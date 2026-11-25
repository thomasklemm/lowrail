#!/usr/bin/env bash
# all.sh GEM: the four apps one after another (so suite times do not share CPUs), then compare.
set -u
here=$(cd "$(dirname "$0")" && pwd); out=$(cd "$here/.." && pwd); repo=$(cd "$here/../../../../.." && pwd)
gem=$1; steps=plain,plain2,off,profiled,base2,head,planted
add='20.times { ERB::Util.html_escape("a<b") }'
PLANT="app/controllers/articles_controller.rb:5a\\    $add" "$here/proof.sh" "$repo/.corpus/rc-blog-floor" "$out/blog-floor" "$gem" $steps,seed99 -- bin/rails test -v
PLANT="app/controllers/pages_controller.rb:28a\\    $add" "$here/proof.sh" "$repo/.corpus/rc-codetriage" "$out/codetriage" "$gem" $steps -- bin/rails test --verbose
PLANT="app/controllers/rooms_controller.rb:11a\\    $add" "$here/proof.sh" "$repo/.corpus/rc-campfire" "$out/campfire" "$gem" $steps -- bin/rails test -v
PLANT="app/controllers/home_controller.rb:39a\\    $add" "$here/proof.sh" "$repo/.corpus/rc-lobsters" "$out/lobsters" "$gem" $steps -- bundle exec rspec --seed 1234 --format documentation
for app in blog-floor:rc-blog-floor codetriage:rc-codetriage campfire:rc-campfire lobsters:rc-lobsters; do
  "$here/compare.sh" "$repo/.corpus/${app#*:}" "$out/${app%%:*}"
done
echo ALL DONE
