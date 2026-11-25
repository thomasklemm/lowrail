#!/usr/bin/env bash
# proof.sh APPDIR OUTDIR GEM STEPS -- TEST COMMAND...
# The install path a stranger takes: GEM (gem build lowrail-profile.gemspec, from gem/) installed with
# `gem install --local` into the app Ruby's gem home, a copy of the Gemfile (Gemfile.lowrail) with only
# `gem "lowrail-profile", VERSION, group: [:development, :test], require: false` added, no RUBYLIB,
# an empty XDG_CACHE_HOME (so the counter is built on the first profile).
# STEPS: comma list of plain*, off*, or a capture name (lowrail-profile, 2 runs, into OUTDIR/<name>).
# A step named planted* runs with PLANT (FILE:SED-EXPR) applied, reverted after; seed* profiles with --seed 99.
set -u
app=$1 out=$2 gem=$3 steps=$4; shift 5
here=$(cd "$(dirname "$0")" && pwd)
v=$(sed 's/ruby-//' "$app/.ruby-version")
export PATH="$(~/.local/bin/mise where ruby@$v)/bin:$PATH"
unset RUBYLIB RUBYOPT BUNDLE_GEMFILE
mkdir -p "$out"; out=$(cd "$out" && pwd)
export XDG_CACHE_HOME="$out/cache"
version=$(basename "$gem" .gem | sed 's/^lowrail-profile-//')
cd "$app"
if [ ! -f Gemfile.lowrail ]; then
  gem install --local --no-document "$gem" > "$out/install.log" 2>&1 || exit 1
  cp Gemfile Gemfile.lowrail; cp Gemfile.lock Gemfile.lowrail.lock
  printf '\ngem "lowrail-profile", "%s", group: [:development, :test], require: false\n' "$version" >> Gemfile.lowrail
  BUNDLE_GEMFILE=Gemfile.lowrail bundle install --prefer-local --quiet >> "$out/install.log" 2>&1 || exit 1
  BUNDLE_GEMFILE=Gemfile.lowrail bundle exec ruby -e 'puts Gem.loaded_specs.fetch("lowrail-profile").full_gem_path' > "$out/installed-from.txt"
fi
dump="-r$here/dump_features.rb"
# The app's files, without what its suite itself writes (logs, tmp, SQLite databases).
tree() { git ls-files -co --exclude-standard -z | grep -zvE '^(log|tmp)/|\.sqlite3(-\w+)?$' | xargs -0 sha256sum | sort -k2; }
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
    *)
      if [[ $s == planted* ]]; then
        git diff --quiet HEAD -- "${PLANT%%:*}" || { echo "${PLANT%%:*} differs from HEAD; not planting" >&2; exit 1; }
        sed -i "${PLANT#*:}" "${PLANT%%:*}"; git diff > "$out/$s.patch"
      fi
      [[ $s == planted* ]] || tree > "$out/tree-before-$s.txt"
      seed=(); [[ $s == seed* ]] && seed=(--seed 99)
      rm -rf "$out/$s"; run $s Gemfile.lowrail bundle exec lowrail-profile "${seed[@]}" --out "$out/$s" -- "$@"
      if [[ $s == planted* ]]; then git checkout -q -- "${PLANT%%:*}"; else tree > "$out/tree-after-$s.txt"
        cmp -s "$out/tree-before-$s.txt" "$out/tree-after-$s.txt" && echo "$s tree unchanged" >> "$out/summary.txt" || echo "$s TREE CHANGED" >> "$out/summary.txt"; fi ;;
  esac
done
