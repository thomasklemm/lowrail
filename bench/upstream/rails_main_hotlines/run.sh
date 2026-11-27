#!/usr/bin/env bash
# run.sh APP TREE: APP's suite (the hot-lines run's apps/APP.sh) under lowrail-profile (2 runs) with Rails at TREE.
# TREE r81 = v8.1.4.1, main = $MAIN_SHA; an app listed in OWN81 keeps its own Rails for r81 (its lock is Rails main
# and it sets load_defaults 8.2, so 8.1 cannot boot it). Output in $OUT/APP/TREE: profiled/, profiled.log,
# install.log, summary.txt (exit, wall, per-run outcome counts).
set -u
here=$(cd "$(dirname "$0")" && pwd)
hl=$here/../profile_hotlines_census
app=$1; tree=$2
R81_SHA=3f290b759c8e2ffe7c257951b1255740751355e4
MAIN_SHA=${MAIN_SHA:-088fc0cf61e4ba0c7987decafacc69adb3e22eec}
OWN81=" campfire "
GEM=${GEM:-/home/user/hl-gem/lowrail-profile-0.1.0.rc1.gem}
OUT=${OUT:-/home/user/rmh-out}
DIR=/home/user/workspace/repo/.corpus/hl-$app
case $tree in
  r81) sha=$R81_SHA; [[ $OWN81 == *" $app "* ]] && sha=own ;;
  main) sha=$MAIN_SHA ;;
  *) echo "tree r81|main" >&2; exit 2 ;;
esac
PREP() { :; }
source "$hl/apps/$app.sh"
~/.local/bin/mise install --quiet ruby@$RUBY >/dev/null 2>&1
export PATH="$(~/.local/bin/mise where ruby@$RUBY)/bin:$HOME/.local/bin:$PATH"
unset RUBYLIB RUBYOPT BUNDLE_GEMFILE
export SEED=1234 DISABLE_SPRING=1 PARALLEL_WORKERS=${PARALLEL_WORKERS:-1}
out=$OUT/$app/$tree; mkdir -p "$out"
export XDG_CACHE_HOME="$OUT/$app/cache"
cd "$DIR"
gem list -i lowrail-profile -v 0.1.0.rc1 >/dev/null || gem install --local --no-document "$GEM" > "$out/install.log" 2>&1
if [ ! -f "Gemfile.$tree.done" ]; then
  ruby "$here/variant.rb" "$DIR" "$tree" "$sha"
  BUNDLE_GEMFILE=Gemfile.$tree bundle install --quiet >> "$out/install.log" 2>&1 \
    || { echo "bundle failed" >> "$out/summary.txt"; tail -20 "$out/install.log" >> "$out/summary.txt"; exit 1; }
  touch "Gemfile.$tree.done"
fi
BUNDLE_GEMFILE=Gemfile.$tree bundle exec ruby -e 'print Gem.loaded_specs["railties"].then { "#{_1.version} #{_1.source.respond_to?(:revision) ? _1.source.revision : "release"}" }' > "$out/rails.txt" 2>&1
export BUNDLE_GEMFILE=$DIR/Gemfile.$tree
PREP
rm -rf "$out/profiled"
t0=$(date +%s.%N)
bundle exec lowrail-profile ${PROFILE_ARGS:-} ${TIMEOUT:+--timeout $TIMEOUT} --out "$out/profiled" -- "${CMD[@]}" > "$out/profiled.log" 2>&1
echo "profiled exit $? wall $(echo "$(date +%s.%N) - $t0" | bc) at $(date -u +%H:%M:%S) rails $(cat "$out/rails.txt")" >> "$out/summary.txt"
ruby "$hl/outcomes.rb" "$out/profiled.log" >> "$out/summary.txt" 2>&1
