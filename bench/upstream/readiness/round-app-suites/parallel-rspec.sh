#!/bin/bash
# parallel-rspec.sh N SPLIT [FILES...]: runs the app's spec files in N rspec processes, the way the app-suite round
# ran Chatwoot (round-robin over the sorted files) and Forem (balanced by file size). Runs inside the suite's bundle,
# with the runner's SPEC_OPTS, so every process writes its own JSON result (rspec_json.rb).
#   WORKER_ENV    per-process environment, %n is the worker number (1..N), e.g. "POSTGRES_DATABASE=app_%n"
#   WORKER_SETUP  run once per process before its specs, with that environment (e.g. a schema load)
#   SPEC_FILES    a find(1) expression for the files (default: every spec/**/*_spec.rb)
# A process whose rspec has printed its summary but hasn't exited a minute later is stopped (Forem's at_exit hang).
set -u
n=$1 split=$2; shift 2
if [ $# -gt 0 ]; then printf '%s\n' "$@"; else eval "find spec ${SPEC_FILES:--name '*_spec.rb'}" | sort; fi > tmp/readiness-files
ruby - "$n" "$split" <<'RUBY'
n, split = ARGV[0].to_i, ARGV[1]
files = File.readlines("tmp/readiness-files", chomp: true)
groups = Array.new(n) { [] }
if split == "size"
  sizes = [0] * n
  files.sort_by { -File.size(_1) }.each { |f| i = sizes.index(sizes.min); groups[i] << f; sizes[i] += File.size(f) }
else
  files.each_with_index { |f, i| groups[i % n] << f }
end
groups.each_with_index { |g, i| File.write("tmp/readiness-w#{i + 1}.files", g.sort.join("\n") + "\n") }
RUBY
declare -A pids
for ((w = 1; w <= n; w++)); do
  grep -q . tmp/readiness-w$w.files || continue
  (
    for kv in ${WORKER_ENV:-}; do export "${kv//%n/$w}"; done
    export TEST_ENV_NUMBER=$w
    [ -z "${WORKER_SETUP:-}" ] || bash -c "$WORKER_SETUP" > tmp/readiness-w$w.setup.log 2>&1 || echo "worker $w: setup failed" >&2
    exec rspec $(cat tmp/readiness-w$w.files) > tmp/readiness-w$w.log 2>&1
  ) &
  pids[$w]=$!
done
while [ ${#pids[@]} -gt 0 ]; do
  sleep 15
  for w in "${!pids[@]}"; do
    p=${pids[$w]}
    if ! kill -0 $p 2>/dev/null; then unset "pids[$w]"; continue; fi
    if grep -qE '^[0-9]+ examples?, [0-9]+ failures?' tmp/readiness-w$w.log; then
      [ -f tmp/readiness-w$w.done ] || { touch tmp/readiness-w$w.done; continue; }
      if [ $(( $(date +%s) - $(stat -c %Y tmp/readiness-w$w.done) )) -ge 60 ]; then
        echo "worker $w: stopped a minute after its summary" >&2; pkill -TERM -P $p; kill -TERM $p
      fi
    fi
  done
done
for ((w = 1; w <= n; w++)); do [ -f tmp/readiness-w$w.log ] && { echo "== worker $w"; tail -n 3 tmp/readiness-w$w.log; }; done
rm -f tmp/readiness-w*.done
