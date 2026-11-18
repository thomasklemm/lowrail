#!/usr/bin/env bash
# Usage: b_safety.sh APPDIR OUTDIR STEPS -- TEST COMMAND...
# STEPS: comma list of plain*,off*,profiled,base2,head. plain: no gem; off: gem listed, unused;
# profiled/base2/head: lowrail-profile (2 runs) into OUTDIR/<step>.
set -u
app=$1; out=$2; steps=$3; shift 4
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../../../.." && pwd)
v=$(sed 's/ruby-//' "$app/.ruby-version")
export PATH="$(~/.local/bin/mise where ruby@$v)/bin:$PATH"
cd "$app"
if [ ! -f Gemfile.lowrail ]; then
  cp Gemfile Gemfile.lowrail; cp Gemfile.lock Gemfile.lowrail.lock
  printf '\ngem "lowrail", path: "%s/gem", group: [:development, :test], require: false\n' "$repo" >> Gemfile.lowrail
  BUNDLE_GEMFILE=Gemfile.lowrail bundle install --quiet || exit 1
fi
mkdir -p "$out"
dump="-r$here/dump_features.rb"
run() { # name gemfile cmd...
  local name=$1 gemfile=$2; shift 2
  rm -rf "$out/$name.features"; mkdir -p "$out/$name.features"
  local t0=$(date +%s.%N)
  LOWRAIL_FEATURES_DIR="$out/$name.features" RUBYOPT="$dump" BUNDLE_GEMFILE=$gemfile SEED=1234 "$@" > "$out/$name.log" 2>&1
  echo "$name exit $? wall $(echo "$(date +%s.%N) - $t0" | bc) at $(date -u +%H:%M:%S)" >> "$out/summary.txt"
}
for s in ${steps//,/ }; do
  case $s in
    plain*) run $s Gemfile "$@" ;;
    off*) run $s Gemfile.lowrail "$@" ;;
    *) rm -rf "$out/$s"; run $s Gemfile.lowrail bundle exec lowrail-profile --out "$out/$s" -- "$@" ;;
  esac
done
