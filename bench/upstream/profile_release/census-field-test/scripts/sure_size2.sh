#!/usr/bin/env bash
# sure_size.sh OUT: Sure (16 workers, bin/rails test test/controllers -v) from the c68afc98 gem.
# A: --keep-runs; samples every 2 s the size of A's run dirs and lowrail-profile's own VmHWM (its report is in-process);
#    /usr/bin/time -v around the capture. Then /usr/bin/time -v `lowrail-profile report A`. B: the default (runs deleted).
set -u
out=$1; app=/home/user/workspace/repo/.corpus/ft-sure; mkdir -p "$out"
export PATH="$(cd /tmp && ~/.local/bin/mise where ruby@3.4.9)/bin:$PATH"; unset RUBYLIB RUBYOPT
export POSTGRES_DB=ft_sure_test POSTGRES_USER=user DB_HOST=localhost REDIS_URL=redis://localhost:6379/8 BUNDLE_GEMFILE=Gemfile.lowrail XDG_CACHE_HOME=$out/cache
cd "$app"
sample() { # dir pid-of-time
  local peak=0 hwm=0
  while kill -0 "$2" 2>/dev/null; do
    s=$(du -sb "$1" 2>/dev/null | cut -f1); [ "${s:-0}" -gt "$peak" ] && peak=$s
    lp=$(pgrep -P "$2" -f lowrail-profile | head -1)
    [ -n "$lp" ] && h=$(awk '/VmHWM/ {print $2}' /proc/$lp/status 2>/dev/null) && [ "${h:-0}" -gt "$hwm" ] && hwm=$h
    sleep 2
  done
  echo "peak_dir_bytes $peak lowrail_profile_vmhwm_kb $hwm"
}
for c in ${SURE_CAPS:-A B}; do
  keep=(); [ $c = A ] && keep=(--keep-runs)
  rm -rf "$out/$c"; t0=$(date +%s)
  /usr/bin/time -v -o "$out/$c.time" bundle exec lowrail-profile "${keep[@]}" --out "$out/$c" -- bin/rails test test/controllers -v > "$out/$c.log" 2>&1 &
  tp=$!; s=$(sample "$out/$c" $tp); wait $tp; st=$?
  echo "$c exit $st wall $(( $(date +%s) - t0 )) s; $s; final_dir $(du -sh "$out/$c" | cut -f1); $(du -sh "$out/$c"/run* 2>/dev/null | tr '\n\t' '  ')" >> "$out/summary.txt"
  if [ $c = A ]; then
    /usr/bin/time -v -o "$out/report-A.time" bundle exec lowrail-profile report "$out/A" > /dev/null 2> "$out/report-A.err"
    echo "report A exit $?; $(grep -E 'Maximum resident|Elapsed' "$out/report-A.time" | tr '\n\t' '  ')" >> "$out/summary.txt"
  fi
done
