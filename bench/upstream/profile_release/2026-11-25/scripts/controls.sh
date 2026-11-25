#!/usr/bin/env bash
# controls.sh APPDIR OUTDIR -- TEST COMMAND...: the off setup as a new process under bundle exec's RUBYOPT
# (bundle exec env CMD), which is how lowrail-profile starts its command; `bundle exec bin/rails` and
# `bundle exec rspec` instead load the script inside Bundler's own process, so Bundler's files load in another order.
set -u
app=$1 out=$(cd "$2" && pwd); shift 3
here=$(cd "$(dirname "$0")" && pwd)
v=$(sed 's/ruby-//' "$app/.ruby-version"); export PATH="$(~/.local/bin/mise where ruby@$v)/bin:$PATH"; unset RUBYLIB RUBYOPT
cd "$app"; rm -rf "$out/off-env.features"; mkdir -p "$out/off-env.features"
LOWRAIL_FEATURES_DIR="$out/off-env.features" RUBYOPT="-r$here/dump_features.rb" BUNDLE_GEMFILE=Gemfile.lowrail SEED=1234 bundle exec env "$@" > "$out/off-env.log" 2>&1
echo "off-env exit $? (control: bundle exec env, a new process under Bundler's RUBYOPT)" >> "$out/summary.txt"
