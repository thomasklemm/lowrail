#!/usr/bin/env bash
# usage: run.sh APP_DIR LABEL [NAME] — one full suite of APP_DIR on LABEL (r409, master, zjit), without system or
# browser tests, fixed seed, deprecation warnings on. Minitest runs `rails test -v`, so every test's name and result
# is logged; RSpec (RUNNER=rspec) also writes per-example JSON next to the log.
# Log: $R3/runs/LABEL/NAME.log (NAME defaults to the app dir's basename).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
app=$(cd "$1" && pwd) label=$2 name=${3:-$(basename "$1")}
source "$here/env.sh" "$label"
log=$R3/runs/$label/$name.log
mkdir -p "$(dirname "$log")"
cd "$app"
export CI_PROGRESS_BAR=0 SEED=${SEED:-4242}
export RUBYOPT="${RUBYOPT:+$RUBYOPT }-W:deprecated"
runner=${RUNNER:-minitest}
# PostgreSQL apps (PG=1): a database per app and Ruby, prefixed r3_, on the local server.
if [ -n "${PG:-}" ]; then
  # libpq's GSSAPI probe segfaults in forked test workers on macOS (also on 4.0.9).
  export PGGSSENCMODE=disable
  export DATABASE_URL="postgres://localhost/r3_${name//-/_}_$label" TEST_DATABASE_URL="postgres://localhost/r3_${name//-/_}_$label"
fi
exclude='spec/{system,features}/**/*_spec.rb'
exclude=${RSPEC_EXCLUDE:-$exclude}
{
  echo "# $name on $label: $(ruby -v) RUBYOPT=$RUBYOPT workers=$PARALLEL_WORKERS seed=$SEED runner=$runner"
  bin/rails db:test:prepare 2>&1 | sed 's/^/prepare: /'
  s=$(date +%s)
  if [ "$runner" = rspec ]; then
    rm -f "${log%.log}.json"
    bundle exec rspec --seed "$SEED" --exclude-pattern "$exclude" \
      --format progress --format json --out "${log%.log}.json" ${TEST_ARGS:-}
  else
    bin/rails test -v --seed "$SEED" ${TEST_ARGS:-}
  fi
  echo "# exit=$? seconds=$(( $(date +%s) - s ))"
} > "$log" 2>&1
tail -4 "$log" | grep -E "runs|examples|exit="
