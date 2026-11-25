#!/usr/bin/env bash
# t8.sh APPDIR RUBY [EXE] : --timeout on a real suite with a test that hangs. HANG=1 dies on TERM, HANG=ignore
# ignores it (a worker stuck where TERM does not reach). Serial and with two parallel workers; what is left running.
set -uo pipefail
app=$1 ruby=$2 exe=${3:-}
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh" "$ruby"
cd "$app"
profile() { if [ -n "$exe" ]; then bundle exec ruby "$exe" "$@"; else bundle exec lowrail-profile "$@"; fi; }
IFS=, read -ra cases <<< "${CASES:-1 1,2 1,1 ignore,2 ignore}"; for case in "${cases[@]}"; do
  set -- $case; workers=$1 hang=$2; out=tmp/lp-hang-$workers-$hang
  start=$(date +%s.%N)
  PARALLEL_WORKERS=$workers HANG=$hang HANG_PID=/tmp/pr/hang.pid profile --timeout 20 --out "$out" -- bin/rails test > "/tmp/pr/t8-$workers-$hang.log" 2>&1
  status=$?; took=$(ruby -e 'printf "%.1f", Time.now.to_f - ARGV[0].to_f' "$start")
  sleep 2
  left=$(ps -eo pid,ppid,pgid,stat,etime,args | grep -E "rails test|Rails test worker" | grep -v grep)
  echo "== workers=$workers hang=$hang: exit $status after ${took}s; capture $(cat $out/capture.json | ruby -rjson -e 'c=JSON.parse(STDIN.read); print c.slice("runs","exit","timed_out").to_json'); out: $(ls $out | tr '\n' ' ')"
  grep -E "^lowrail-profile:" "/tmp/pr/t8-$workers-$hang.log" | cut -c1-200
  if [ -n "$left" ]; then echo "LEFT RUNNING:"; echo "$left" | cut -c1-200; echo "$left" | awk '{print $1}' | xargs -r kill -9; else echo "nothing left running"; fi
done
