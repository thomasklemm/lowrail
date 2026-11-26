#!/usr/bin/env bash
# post.sh APP: checks on /home/user/ft/out/APP after ft.sh.
set -u
here=$(cd "$(dirname "$0")" && pwd); repo=/home/user/workspace/repo
m4=$repo/bench/upstream/profile_release/2026-11-25/scripts
final=$repo/bench/upstream/profile_release/2026-11-25-final/scripts
app=$1; PLANT_RE='output_safety|erb/util'
source "$here/apps/$app.sh"
[ -n "${PLANT_ACTION:-}" ] && PLANT_RE="$PLANT_RE|$PLANT_ACTION"
o=/home/user/ft/out/$app
v=$(sed 's/ruby-//' "$APPDIR/.ruby-version"); export PATH="$(~/.local/bin/mise where ruby@$v)/bin:$PATH"
unset RUBYLIB RUBYOPT
c() { (cd "$APPDIR" && BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile compare "$@"); }
caps=$(cd "$o" && find . -maxdepth 1 -type d -name 'u[0-9]*' ! -name '*.*' -printf '%f\n' | sort -V)
logs=$(cd "$o" && ls plain*.log off*.log u*.log planted*.log seed*.log 2>/dev/null)
# Outcomes: every run of a capture prints its tests into the same log; split per run first.
(cd "$o" && ruby "$here/split_runs.rb" $logs) > "$o/outcomes.txt" 2>&1
{ for f in "$o"/*.outcomes; do cmp -s "$o/plain.outcomes" "$f" && echo "$(basename "$f") = plain" || echo "$(basename "$f") DIFFERS ($(diff "$o/plain.outcomes" "$f" | grep -c '^[<>]') lines)"; done; } >> "$o/outcomes.txt"
rej=(); [ -n "${FEATURES_REJECT:-}" ] && rej=("$FEATURES_REJECT")
{ echo "# plain vs plain2, off"; ruby "$m4/features_cmp.rb" "$o" plain plain2,off "${rej[@]}"
  echo "# off-env vs captures"; ruby "$m4/features_cmp.rb" "$o" off-env "$(echo $caps planted planted2 seed99 | tr ' ' ,)" "${rej[@]}"; } > "$o/features.txt" 2>&1
# The README CI job: base u1, base2 u2, head u3, head2 u4 on exit 1; and with the plants as head and head2.
{
  c "$o/u1/report.json" "$o/u3/report.json" --aa "$o/u2/report.json" > "$o/cijob-unchanged-1.md"; s=$?; echo "unchanged compare exit $s"
  if [ $s = 1 ]; then c "$o/u1/report.json" "$o/u4/report.json" --aa "$o/u2/report.json" > "$o/cijob-unchanged-2.md"; echo "unchanged head2 exit $?"; fi
  c "$o/u1/report.json" "$o/planted/report.json" --aa "$o/u2/report.json" > "$o/cijob-planted-1.md"; s=$?; echo "planted compare exit $s"
  c "$o/u1/report.json" "$o/planted/report.json" --aa "$o/u2/report.json" --json > "$o/cijob-planted-1.json"
  if [ $s = 1 ]; then c "$o/u1/report.json" "$o/planted2/report.json" --aa "$o/u2/report.json" > "$o/cijob-planted-2.md"; echo "planted head2 exit $?"; fi
  c "$o/u1/report.json" "$o/u3/report.json" > "$o/compare-noaa.md"; echo "without --aa exit $?"
  c "$o/u1/report.json" "$o/seed99/report.json" --aa "$o/u2/report.json" > "$o/compare-seed99.md"; echo "seed99 exit $?"
  (cd "$APPDIR" && BUNDLE_GEMFILE=Gemfile.lowrail bundle exec lowrail-profile report "$o/u1" > /dev/null 2> "$o/report-again.err"); echo "report again exit $?"
} > "$o/exits.txt" 2>&1
ruby -I"$repo/gem/lib" "$m4/margin.rb" "$o/u1/report.json" "$o/u3/report.json" "$o/u2/report.json" > "$o/margin.txt" 2>&1
ruby -I"$repo/gem/lib" "$final/gate.rb" "$PLANT_RE" $(for d in $caps; do echo "$o/$d"; done) -- "$o/planted" "$o/planted2" > "$o/gate.txt" 2>&1
ruby "$here/overhead.rb" "$o" > "$o/overhead.txt" 2>&1
