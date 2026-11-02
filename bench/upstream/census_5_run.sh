#!/usr/bin/env bash
# Census 5 runner for the census-4 harness, from the Lowrail root.
#   bench/upstream/census_5_run.sh app APP MODE CMD [OUT]   one app (prepare|profile|list|callers)
#   bench/upstream/census_5_run.sh all LABEL                 all ten configurations, interpreter then YJIT
#   bench/upstream/census_5_run.sh patched LABEL PATCH...    patch the shared bundled Rails checkout,
#                                                            run all, then restore it from a pristine copy
# App copies live in .corpus/census5-APP (dependency overlays in
# fixtures/corpus/rails-main-census-5). Output goes to
# .lowrail/private/rails-main-census-5/LABEL. Services: PostgreSQL 15 on the
# local socket (CodeTriage, PingCRM), MySQL 8.4 on 127.0.0.1:3307 as root
# (fizzy-mysql), memcached (CodeTriage) and Redis.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
pin=${CENSUS_RAILS_PIN:-5810776eecc5b2e50b58e81ee0c26c02c718fdf0}
apps="blog campfire writebook fizzy fizzy-mysql codetriage pingcrm redprints-cfp react-starter-kit lobsters"
ruby_bin="$(mise where ruby@4.0.7)/bin"
rails_dir() { echo "$("$ruby_bin/ruby" -e 'print Gem.dir')/bundler/gems/rails-${pin:0:12}"; }

run_app() {
  local a=$1 mode=$2 cmd=$3 out=${4:-}
  export BUNDLE_FROZEN=true RAILS_ENV=production RACK_ENV=production SECRET_KEY_BASE_DUMMY=1 \
    RAILS_LOG_LEVEL=fatal SKIP_TELEMETRY=1 APP_VERSION=census APP_HOST=localhost RUBY_YJIT_ENABLE=0 \
    RUBY_ZJIT_ENABLE=0 CENSUS_MODE=$mode CENSUS_RAILS_PIN=$pin PATH="$ruby_bin:$PATH"
  case $a in
    codetriage|pingcrm) export DATABASE_ADAPTER=postgresql ;;
    fizzy-mysql) export DATABASE_ADAPTER=mysql MYSQL_USER=root MYSQL_HOST=127.0.0.1 MYSQL_PORT=3307 ;;
  esac
  unset RUBYOPT
  cd "$root/.corpus/census5-$a"
  local yjit=()
  [ "$mode" = yjit ] && yjit=(--yjit)
  if [ "$cmd" = callers ]; then
    exec bundle exec ruby "${yjit[@]}" "$root/bench/upstream/census_4_callers.rb" "$a"
  fi
  exec bundle exec ruby "${yjit[@]}" "$root/bench/upstream/rails_main_census_4.rb" "$cmd" "$a" $out
}

run_all() {
  local out="$root/.lowrail/private/rails-main-census-5/$1"
  mkdir -p "$out"
  for mode in interpreter yjit; do
    for a in $apps; do
      ("$0" app "$a" "$mode" profile "$out/$a-$mode.json" > "$out/$a-$mode.log" 2>&1) &
    done
    wait
  done
  for a in $apps; do for mode in interpreter yjit; do
    [ -s "$out/$a-$mode.json" ] || echo "missing $a-$mode" >&2
  done; done
}

case ${1:?command} in
  app) shift; run_app "$@" ;;
  all) run_all "${2:?label}" ;;
  patched)
    label=${2:?label}; shift 2
    rails=$(rails_dir); pristine="$rails.pristine"
    [ -d "$pristine" ] || cp -a "$rails" "$pristine"
    trap 'rm -rf "$rails" && cp -a "$pristine" "$rails"' EXIT
    for p in "$@"; do patch -s -p1 -d "$rails" < "$p"; done
    run_all "$label" ;;
  *) echo "usage: $0 app|all|patched ..." >&2; exit 2 ;;
esac
