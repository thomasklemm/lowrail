#!/usr/bin/env bash
# confirm.sh APP TREE FILE...: the hot-lines command for APP on FILE..., plainly (no profiler), with Gemfile.TREE.
set -u
app=$1; tree=$2; shift 2
hl=/home/user/workspace/repo/bench/upstream/profile_hotlines_census
DIR=/home/user/workspace/repo/.corpus/hl-$app
PREP() { :; }
source "$hl/apps/$app.sh"
export PATH="$(~/.local/bin/mise where ruby@$RUBY)/bin:$HOME/.local/bin:$PATH"
unset RUBYLIB RUBYOPT
export SEED=1234 DISABLE_SPRING=1 PARALLEL_WORKERS=1 XDG_CACHE_HOME=/home/user/rmh-out/$app/cache
cd "$DIR"; export BUNDLE_GEMFILE=$DIR/Gemfile.$tree
case ${CMD[1]} in
  exec) bundle exec rspec "$@" --seed 1234 --format documentation ;;
  *) bin/rails test "$@" -v ;;
esac
