#!/usr/bin/env bash
# run.sh APP [STEPS]: APP's suite plain (own Gemfile) and profiled (Gemfile.lowrail, lowrail-profile, 2 runs),
# with apps/APP.sh giving RUBY, CMD (array), PREP (optional function) and exported env.
# Output in $OUT/APP: plain.log, profiled.log, profiled/ (capture), summary.txt.
set -u
here=$(cd "$(dirname "$0")" && pwd)
app=$1; steps=${2:-plain,profiled}
GEM=${GEM:-/home/user/hl-gem/lowrail-profile-0.1.0.rc1.gem}
OUT=${OUT:-/home/user/hl-out}
DIR=/home/user/workspace/repo/.corpus/hl-$app
TIMEOUT=${TIMEOUT:-}
PREP() { :; }
source "$here/apps/$app.sh"
export PATH="$(~/.local/bin/mise where ruby@$RUBY)/bin:$PATH"
unset RUBYLIB RUBYOPT BUNDLE_GEMFILE
export SEED=1234 DISABLE_SPRING=1 PARALLEL_WORKERS=${PARALLEL_WORKERS:-1}
out=$OUT/$app; mkdir -p "$out"
export XDG_CACHE_HOME="$out/cache"
cd "$DIR"
if [ ! -f Gemfile.lowrail ]; then
  gem install --local --no-document "$GEM" > "$out/install.log" 2>&1 || { echo "gem install failed" >> "$out/summary.txt"; exit 1; }
  cp Gemfile Gemfile.lowrail; cp Gemfile.lock Gemfile.lowrail.lock
  printf '\ngem "lowrail-profile", "0.1.0.rc1", group: [:development, :test], require: false\n' >> Gemfile.lowrail
  BUNDLE_GEMFILE=Gemfile.lowrail bundle install --prefer-local --quiet >> "$out/install.log" 2>&1 || { echo "Gemfile.lowrail bundle failed" >> "$out/summary.txt"; exit 1; }
fi
PREP
run() { # name gemfile cmd...
  local name=$1 gemfile=$2; shift 2
  local t0=$(date +%s.%N)
  BUNDLE_GEMFILE=$gemfile "$@" > "$out/$name.log" 2>&1
  echo "$name exit $? wall $(echo "$(date +%s.%N) - $t0" | bc) at $(date -u +%H:%M:%S)" >> "$out/summary.txt"
}
for s in ${steps//,/ }; do
  case $s in
    plain*) run $s Gemfile "${CMD[@]}" ;;
    *) rm -rf "$out/$s"
       run $s Gemfile.lowrail bundle exec lowrail-profile ${PROFILE_ARGS:-} ${TIMEOUT:+--timeout $TIMEOUT} --out "$out/$s" -- "${CMD[@]}" ;;
  esac
done
ruby "$here/outcomes.rb" "$out"/plain*.log "$out"/profiled*.log >> "$out/summary.txt" 2>&1
