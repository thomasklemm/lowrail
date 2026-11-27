#!/usr/bin/env bash
# One label: objects and Callgrind (interpreter, or MODE=yjit) for every op, written to OUT/LABEL-{objects,cpu}.json.
#   OUT=dir LABEL=sq-rel-a STACK=rel|main|cand DB=sqlite|pg [MODE=interp|yjit] [RUBY=4.0.10] bench/upstream/solid_stack/run.sh
# APP defaults to ~/w/stackapp (bench/upstream/solid_stack/setup.sh); VALGRIND to ~/w/c8-valgrind (script/cpu-census build).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
app=${APP:-$HOME/w/stackapp}
ruby_bin="$(~/.local/bin/mise where ruby@"${RUBY:-4.0.10}")/bin"
export PATH="$ruby_bin:$PATH" APP="$app"
[[ ${STACK:-rel} == rel ]] && export BUNDLE_GEMFILE="$app/Gemfile" || export BUNDLE_GEMFILE="$app/Gemfile.$STACK"
[[ ${DB:-sqlite} == pg ]] && export DB=pg || unset DB
flags=()
[[ ${MODE:-interp} == yjit ]] && flags=(--yjit)
mkdir -p "$OUT"
cd "$app"
ruby -rbundler/setup "${flags[@]}" "$here/harness.rb" objects "$OUT/$LABEL-objects.json" > /dev/null 2> "$OUT/$LABEL-objects.log"
CENSUS_CPU_EXT=${CENSUS_CPU_EXT:-$HOME/w/sampler/census_cpu_sampler.so} \
  sh -c 'ulimit -d unlimited; exec "$@"' sh "${VALGRIND:-$HOME/w/c8-valgrind}/bin/valgrind" --tool=callgrind \
  --instr-atstart=no --collect-atstart=yes --max-threads=2000 --callgrind-out-file=/tmp/solid-stack-%p.out \
  "$ruby_bin/ruby" -rbundler/setup "${flags[@]}" "$here/harness.rb" cpu "$OUT/$LABEL-cpu.json" > /dev/null 2> "$OUT/$LABEL-cpu.log"
rm -f /tmp/solid-stack-*.out
