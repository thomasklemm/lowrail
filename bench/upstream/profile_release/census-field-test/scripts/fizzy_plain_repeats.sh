#!/usr/bin/env bash
# fizzy_plain_repeats.sh OUT N: Fizzy's suite without lowrail-profile (its own Gemfile, SEED=1234), N times, each under
# timeout(1) 30 s (the profiled runs take 6–13 s): does the hung-worker case happen without the profiler too?
out=$1 n=$2; mkdir -p "$out"; app=/home/user/workspace/repo/.corpus/ft-fizzy
export PATH="$(cd /tmp && ~/.local/bin/mise where ruby@4.0.7)/bin:$PATH"; unset RUBYLIB RUBYOPT BUNDLE_GEMFILE
export CI_PROGRESS_BAR=0 SEED=1234; cd "$app"
for i in $(seq 1 "$n"); do
  t0=$(date +%s.%N); timeout -k 10 30 bin/rails test -v > "$out/p$i.log" 2>&1; s=$?
  echo "p$i exit $s wall $(echo "$(date +%s.%N) - $t0" | bc) tests $(grep -acE '= [0-9.]+ s = ' "$out/p$i.log") $(grep -a 'runs, ' "$out/p$i.log")" >> "$out/summary.txt"
  for p in $(ps -eo pid=,comm= | awk '$2 ~ /ruby|rails|Rails|worker/ {print $1}'); do [ "$(readlink /proc/$p/cwd 2>/dev/null)" = "$app" ] && kill -9 $p; done
done
