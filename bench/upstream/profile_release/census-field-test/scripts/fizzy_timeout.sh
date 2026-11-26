#!/usr/bin/env bash
# fizzy_timeout.sh OUT N TIMEOUT [hang]: N Fizzy captures (bin/rails test -v, its default 16 workers) from the c68afc98 gem,
# each with --timeout TIMEOUT; per run: wall time from stderr timestamps; then exit, capture.json, outcomes, leftover processes.
set -u
here=$(cd "$(dirname "$0")" && pwd); out=$1 n=$2 t=$3 hang=${4:-}
app=/home/user/workspace/repo/.corpus/ft-fizzy
export PATH="$(cd /tmp && ~/.local/bin/mise where ruby@4.0.7)/bin:$PATH"; unset RUBYLIB RUBYOPT
export CI_PROGRESS_BAR=0 BUNDLE_GEMFILE=Gemfile.lowrail XDG_CACHE_HOME=$out/cache
mkdir -p "$out"; cd "$app"
for i in $(seq 1 "$n"); do
  c=$out/c$i; rm -rf "$c"; extra=()
  [ -n "$hang" ] && extra=(env FT_HANG=1 FT_HANG_MARK=$out/c$i.hung RUBYOPT=-r$here/hang.rb)
  t0=$(date +%s.%N)
  "${extra[@]}" bundle exec lowrail-profile --timeout "$t" --out "$c" -- bin/rails test -v 2>&1 \
    | while IFS= read -r l; do printf '%s %s\n' "$(date +%s.%N)" "$l"; done > "$c.log"
  s=${PIPESTATUS[0]}; t1=$(date +%s.%N)
  sleep 1
  mine() { for p in $(ps -eo pid=,comm= | awk '$2 ~ /^(ruby|rails|Rails)/ || $2 ~ /worker/ {print $1}'); do [ "$(readlink /proc/$p/cwd 2>/dev/null)" = "$app" ] && echo $p; done; }
  left=$(mine | wc -l)
  runs=$(ruby -e 'ls=File.readlines(ARGV[0]); st=ls.grep(/lowrail-profile: run \d+ of/).map { _1.to_f }; fin=ls.last.to_f; st.each_with_index.map { |a,i| ((st[i+1]||ls.grep(/lowrail-profile: (no report|report in|run \d+ took)/).first.to_f.then { |x| x>0 ? x : fin })-a).round(1) }.then { puts _1.join(",") }' "$c.log")
  echo "c$i exit $s wall $(echo "$t1 - $t0" | bc) runs_wall $runs capture $(cat $c/capture.json 2>/dev/null | tr -d '\n') leftover $left $(grep -h 'runs, ' $c.log | sed 's/^[0-9.]* //' | tr '\n' '|') $(grep -o 'run [0-9] took longer[^;]*' $c.log | tr '\n' ' ')" >> "$out/summary.txt"
  if [ "$left" -gt 0 ]; then ps -o pid,ppid,stat,etime,args -p "$(mine | paste -sd,)" > "$out/c$i.leftover"; kill -9 $(mine) 2>/dev/null; fi
done
