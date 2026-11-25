#!/usr/bin/env bash
# t4.sh APPDIR OUTDIR RUBY -- COMMAND... : the suite plain (bundle exec COMMAND) and profiled, with and without a
# caller SEED/SPEC_OPTS and with two parallel workers: per-test outcomes, the tree, and what child processes see.
set -uo pipefail
app=$1 outdir=$2 ruby=$3; shift 4
here=$(cd "$(dirname "$0")" && pwd); . "$here/../env.sh" "$ruby"
cd "$app"
tree() {
  git status --porcelain --ignored | sort
  find . -path ./.git -prune -o -path ./tmp -prune -o -path ./log -prune -o -path ./storage -prune -o -path ./db/test.sqlite3 -prune -o -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum
}
outcomes() { grep -aE "$PATTERN" | sed -E 's/ = [0-9.]+ s = / = /; s/ \([0-9.]+ seconds?\)//; s/^Finished in .*//' | sort; }
: "${PATTERN:= = [0-9.]+ s = }"
for variant in ${VARIANTS:-noseed seed99 par2}; do
  case $variant in
    noseed) envs=(env -u SEED -u SPEC_OPTS -u PARALLEL_WORKERS) ;;
    seed99) envs=(env -u PARALLEL_WORKERS SEED=99 SPEC_OPTS=--no-color) ;;
    par2) envs=(env -u SEED -u SPEC_OPTS PARALLEL_WORKERS=2) ;;
    serial) envs=(env -u SEED -u SPEC_OPTS PARALLEL_WORKERS=1) ;;
  esac
  for mode in plain profiled; do
    out=$outdir/$variant-$mode; rm -rf "$out"; mkdir -p "$out/probe"
    tree > "$out/tree-before.txt"
    if [ $mode = plain ]; then
      "${envs[@]}" PROBE_OUT="$out/probe" bundle exec "$@" > "$out/log.txt" 2>&1; echo $? > "$out/status"
      outcomes < "$out/log.txt" > "$out/outcomes.txt"
    else
      "${envs[@]}" PROBE_OUT="$out/probe" bundle exec lowrail-profile --out "tmp/lp-$variant" ${PROFILE_ARGS:-} -- "$@" > "$out/log.txt" 2>&1; echo $? > "$out/status"
      awk -v d="$out" '/^lowrail-profile: run [0-9]+ of/ { n = $3 } /^# lowrail-profile:/ { n = "report" } { print > (d "/run" n ".txt") }' "$out/log.txt"
      for r in 1 2; do outcomes < "$out/run$r.txt" > "$out/outcomes-run$r.txt"; done
    fi
    tree > "$out/tree-after.txt"
    sleep 1; ps -eo pid,ppid,pgid,stat,args | grep -F "$app" | grep -vE "t4\.sh|grep|ps -eo" > "$out/leftover.txt" || true
  done
  p=$outdir/$variant-plain q=$outdir/$variant-profiled
  echo "== $variant: status plain $(cat $p/status) profiled $(cat $q/status); tests $(wc -l < $p/outcomes.txt)"
  for r in 1 2; do cmp -s "$p/outcomes.txt" "$q/outcomes-run$r.txt" && echo "outcomes run$r identical" || { echo "outcomes run$r DIFFER"; diff "$p/outcomes.txt" "$q/outcomes-run$r.txt" | head -10; }; done
  echo "tree plain:    $(diff $p/tree-before.txt $p/tree-after.txt | tr '\n' ' ')"
  echo "tree profiled: $(diff $q/tree-before.txt $q/tree-after.txt | tr '\n' ' ')"
  for f in "$p"/probe/*.txt; do n=$(basename "$f"); cmp -s "$f" "$q/probe/$n" && echo "child $n identical" || { echo "child $n DIFFERS"; diff "$f" "$q/probe/$n" | head -12; }; done
  echo "leftover: $(cat $q/leftover.txt | wc -l)"
done
