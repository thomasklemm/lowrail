#!/usr/bin/env bash
# Profile census apps (see census_prof.rb): census_prof.sh OUTDIR APP...
# Uses each copy's base variant bundle, interpreter then YJIT, one app at a time.
set -euo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
out=$(realpath -m "$1"); shift
mkdir -p "$out"
for app in "$@"; do
  dir="$root/.corpus/census-$app"
  sha=$(ruby -rjson -e 'print JSON.parse(File.read(ARGV[0])).dig("base", "sha")' "$dir/.census.json")
  for mode in interpreter yjit; do
    flag=(); [[ $mode == yjit ]] && flag=(--yjit)
    adapter=sqlite; [[ $app == pingcrm || $app == codetriage ]] && adapter=postgresql
    (cd "$dir" && env APP_HOST=localhost DATABASE_ADAPTER="$adapter" RUBY_YJIT_ENABLE=0 CENSUS_RAILS_SHA="$sha" CENSUS_MODE="$mode" BUNDLE_GEMFILE="$dir/Gemfile.census-${sha:0:12}" \
      DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec ruby "${flag[@]}" "$root/bench/upstream/arcpu/census_prof.rb" \
      "$app" "$out/$app-$mode.dump" "${REPS:-40}") > "$out/$app-$mode.log" 2>&1
    echo "$app $mode done"
  done
done
