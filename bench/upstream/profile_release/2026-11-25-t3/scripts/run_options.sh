#!/usr/bin/env bash
# run_options.sh SET: options.rb on one capture set, into ../options-SET.txt (from this directory's parent).
cd "$(dirname "$0")/.."
P=.. O=../../../../.amp/in/orb-backup
R=$(~/.local/bin/mise where ruby@4.0.7)/bin/ruby
run() { $R -I../../../../gem/lib scripts/options.rb "$@"; }
B="$P/2026-11-25/blog-floor $P/2026-11-25-fixes/blog-floor $P/2026-11-25-confirm-opus/blog-floor"
case $1 in
  blog) run "Blog, Ruby 3.3.14 / Rails 7.2.4, one process" 'output_safety|erb/util' $(for d in $B; do echo $d/profiled $d/base2 $d/head; done) \
    $P/2026-11-25-confirm-opus/blog-floor/aa{3,4,5} -- $(for d in $B; do echo $d/planted; done) ;;
  fresh-parallel) run "Fresh app, Ruby 4.0.7 / Rails 8.1.4.1, 2 workers" 'x^' $(for i in $(seq 1 24); do echo $P/2026-11-25-final/fresh-81/c$i; done) ;;
  fresh-serial) run "Fresh app, PARALLEL_WORKERS=1" 'x^' $(for i in $(seq 1 12); do echo fresh-81/s$i; done) ;;
  campfire-parallel) run "Campfire, 8 workers" 'output_safety|erb/util|RoomsController#show' $P/2026-11-25/campfire/{profiled,base2,head} -- $P/2026-11-25/campfire/planted $P/2026-11-25-final/campfire/planted2 ;;
  campfire-serial) run "Campfire, PARALLEL_WORKERS=1" 'output_safety|erb/util|RoomsController#show' campfire/s{1,2,3,4} -- campfire/planted campfire/planted2 ;;
  codetriage) run "CodeTriage, one process" 'output_safety|erb/util|PagesController' $P/2026-11-25/codetriage/{profiled,base2,head} -- $P/2026-11-25/codetriage/planted $P/2026-11-25-final/codetriage/planted2 ;;
  lobsters) run "Lobsters, one process" 'output_safety|erb/util|HomeController' $P/2026-11-25/lobsters/{profiled,base2,head} -- $P/2026-11-25/lobsters/planted $P/2026-11-25-final/lobsters/planted2 ;;
  osm-parallel) run "openstreetmap-website, 8 workers" 'x^' $O/osm/lowrail-profile{,-aa,-head,-head2} ;;
  osm-serial) run "openstreetmap-website, PARALLEL_WORKERS=1" 'NotesController#index|x^' $O/osm-serial/s{1,2,3,4} -- $O/osm-serial/s5 ;;
  hackatime-serial) run "Hackatime, PARALLEL_WORKERS=1" 'LeaderboardsController#index|output_safety|erb/util' census/$1/s{1,2,3,4,5,6} -- census/$1/splanted{,2} ;;
  writebook-serial) run "Writebook, PARALLEL_WORKERS=1" 'SessionsController#create|output_safety|erb/util' census/$1/s{1,2,3,4,5,6} -- census/$1/splanted{,2} ;;
  hackatime|writebook|writebook-w4)
    case $1 in hackatime) n="Hackatime, 2 workers"; re='LeaderboardsController#index|output_safety|erb/util' ;;
      writebook) n="Writebook, 16 workers"; re='BooksController#index|output_safety|erb/util' ;;
      writebook-w4) n="Writebook, PARALLEL_WORKERS=4"; re='BooksController#index|output_safety|erb/util' ;; esac
    run "$n" "$re" census/$1/u{1,2,3,4,5,6} -- census/$1/planted census/$1/planted2 ;;
esac > "options-$1.txt" 2>&1
echo "$1 done"
