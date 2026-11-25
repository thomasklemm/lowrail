#!/usr/bin/env bash
# misc.sh FRESH_APP RSPEC_APP FIX_EXE : the smaller checks. RSpec app (Ruby 3.3.14): a Bundler.with_unbundled_env
# child when lowrail-profile is not under `bundle exec`; T2. Fresh app (Ruby 4.0.7): --out with glob characters;
# --timeout under a pty; --timeout with the fix where the worker exits on TERM.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); fresh=$1 rspec=$2 fix=$3
(
  . "$here/env.sh" 3.3.14; cd "$rspec"
  for exe in "$(gem contents lowrail-profile | grep exe/lowrail-profile)" "$fix"; do
    rm -rf /tmp/pr/miscprobe; mkdir -p /tmp/pr/miscprobe
    PROBE_OUT=/tmp/pr/miscprobe ruby "$exe" --out tmp/lp-nb -- bundle exec rspec > /dev/null 2>&1
    echo "not under bundle exec, $([ "$exe" = "$fix" ] && echo fixed || echo built gem): exit $?; with_unbundled_env child: $(grep -E '^(SEED|profiler)=' /tmp/pr/miscprobe/after_suite_unbundled_env_ruby.txt | tr '\n' ' '); tree: $(git status --short | tr '\n' ' ')"
    git checkout -q swagger
  done
  mkdir -p spec/controllers
  printf 'require "rails_helper"\nRSpec.describe ArticlesController, type: :controller do\n  it("calls the controller directly") { 3.times { get :index }; expect(response).to be_successful }\nend\n' > spec/controllers/articles_controller_spec.rb
  bundle exec lowrail-profile --out tmp/lp-t2 -- rspec spec/controllers > /tmp/pr/misc.log 2>&1
  echo "T2 controller specs only: exit $?; $(grep -o 'no report: no runs with requests, jobs or mails' /tmp/pr/misc.log)"
  for specs in "spec/requests/probe_spec.rb" "spec/requests/probe_spec.rb spec/controllers"; do
    bundle exec lowrail-profile --out tmp/lp-t2 -- rspec $specs > /tmp/pr/misc.log 2>&1
    echo "T2 $specs: exit $?; $(grep Counted /tmp/pr/misc.log)"
  done
  rm -rf spec/controllers tmp/lp-t2 tmp/lp-nb; git checkout -q swagger
)
. "$here/env.sh" 4.0.7; cd "$fresh"
rm -rf tmp/g
PARALLEL_WORKERS=1 bundle exec lowrail-profile --keep-runs --out tmp/g/keep -- bin/rails test test/controllers > /dev/null 2>&1
PARALLEL_WORKERS=1 bundle exec lowrail-profile --out 'tmp/g/{keep,x}' -- bin/rails test test/controllers > /dev/null 2>&1
echo "--out 'tmp/g/{keep,x}': exit $?; tmp/g/keep: $(ls tmp/g/keep | tr '\n' ' '); tmp/g/{keep,x}: $(ls 'tmp/g/{keep,x}' | tr '\n' ' ')"
PARALLEL_WORKERS=1 bundle exec lowrail-profile --out 'tmp/g/[x]' -- bin/rails test test/controllers > /tmp/pr/misc.log 2>&1
echo "--out 'tmp/g/[x]': exit $?; $(grep -o 'no report: no runs with requests' /tmp/pr/misc.log); tmp/g/[x]: $(ls 'tmp/g/[x]' | tr '\n' ' ')"
rm -rf tmp/g
start=$(date +%s)
script -qfc "bundle exec lowrail-profile --timeout 5 --out tmp/lp-tty -- ruby -e 'p STDIN.gets'" /dev/null < /dev/null > /tmp/pr/misc.log 2>&1
echo "--timeout 5 under a pty, a command that reads the terminal: $(( $(date +%s) - start )) s; $(tr -d '\r' < /tmp/pr/misc.log | grep -o 'run 1 took longer than --timeout 5.0s')"
CASES="2 1" "$here/t8.sh" "$fresh" 4.0.7 "$fix" | head -1 | sed 's/^== /with the fix, /'
