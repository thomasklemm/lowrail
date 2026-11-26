#!/usr/bin/env bash
# app.sh APP [STEPS]: plain once, 8 unchanged one-process captures (s1-s8), 2 planted (planted, planted2), for Forem or OSM,
# with the OSS sweep's setup and command. Forem's s3 and s6 were rejected (README); STEPS reran s6-s8, the plants and s9. Resumable: steps with a line in summary.txt are skipped.
set -u
app=$1 out=/home/user/cal/out/$1
mkdir -p "$out"
export PARALLEL_WORKERS=1
unset RUBYLIB RUBYOPT BUNDLE_GEMFILE
case $app in
  forem)
    dir=/home/user/oss/forem
    export PATH=$HOME/.local/share/mise/installs/ruby/3.3.14/bin:$(~/.local/bin/mise where node@22)/bin:$PATH
    export RAILS_ENV=test DATABASE_URL_TEST=postgres://postgres:postgres@localhost:5432/Forem_test REDIS_URL=redis://localhost:6379
    file=app/controllers/stories_controller.rb; sedx='46a\    20.times { ERB::Util.html_escape("a<b") }'
    plain=(bundle exec rspec spec/requests --seed 1234 --format documentation)
    cmd=(bundle exec rspec spec/requests --format documentation) ;;
  osm)
    dir=/home/user/oss/openstreetmap-website
    export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH RAILS_ENV=test OPENSTREETMAP_MEMCACHE_SERVERS=127.0.0.1
    file=app/controllers/notes_controller.rb; sedx='22a\    Array.new(200) { Object.new }'
    plain=(env SEED=1234 bin/rails test -v)
    cmd=(bin/rails test -v) ;;
esac
export XDG_CACHE_HOME=$out/cache
cd "$dir"
tree() { git ls-files -co --exclude-standard -z | grep -zvE '^(log|tmp|node_modules|public/assets|app/assets/builds)/' | xargs -0 sha256sum | sort -k2; }
for s in ${2:-plain s1 s2 s3 s4 s5 s6 s7 s8 planted planted2}; do
  grep -q "^$s exit" "$out/summary.txt" 2>/dev/null && continue
  git checkout -q -- "$file"
  # Forem's specs leave a directory per user id under public/uploads (gitignored); after about 11 suite runs it
  # reached ext4's 65,000 links and run 2 of the first s6 failed with Errno::EMLINK.
  [ $app = forem ] && rm -rf public/uploads
  if [[ $s == planted* ]]; then sed -i "$sedx" "$file"; git diff -- "$file" > "$out/$s.patch"; else tree > "$out/tree-before-$s.txt"; fi
  t0=$(date +%s.%N)
  if [ $s = plain ]; then "${plain[@]}" > "$out/$s.log" 2>&1
  else rm -rf "tmp/cal-$s"; bundle exec lowrail-profile --out "tmp/cal-$s" -- "${cmd[@]}" > "$out/$s.log" 2>&1; fi
  st=$?
  echo "$s exit $st wall $(echo "$(date +%s.%N) - $t0" | bc) at $(date -u +%H:%M:%S)" >> "$out/summary.txt"
  if [ $s != plain ]; then mkdir -p "$out/$s"; cp tmp/cal-$s/report.json tmp/cal-$s/capture.json tmp/cal-$s/command.txt tmp/cal-$s/report.md "$out/$s/" 2>/dev/null; fi
  if [[ $s == planted* ]]; then git checkout -q -- "$file"; else tree > "$out/tree-after-$s.txt"
    cmp -s "$out/tree-before-$s.txt" "$out/tree-after-$s.txt" && echo "$s tree unchanged" >> "$out/summary.txt" || echo "$s TREE CHANGED" >> "$out/summary.txt"; fi
done
grep -q "ALL DONE" "$out/summary.txt" || echo ALL DONE >> "$out/summary.txt"
exec sleep infinity
