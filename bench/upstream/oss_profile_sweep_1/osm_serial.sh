#!/usr/bin/env bash
# osm_serial.sh: serial OSM captures s1-s4 unchanged, s5 with a planted loop in NotesController#index.
set -u
cd /home/user/oss/openstreetmap-website
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH RAILS_ENV=test OPENSTREETMAP_MEMCACHE_SERVERS=127.0.0.1
D=/home/user/workspace/repo/.amp/in/orb-backup/osm-reports
for s in s1 s2 s3 s4 s5; do
  if [ $s = s5 ]; then
    sed -i '22a\    Array.new(200) { Object.new }' app/controllers/notes_controller.rb
    git diff > /home/user/oss/logs/osm-s5.patch
  fi
  start=$(date +%s)
  PARALLEL_WORKERS=1 bundle exec lowrail-profile --out tmp/lowrail-profile-$s -- bin/rails test -v > /home/user/oss/logs/osm-$s.log 2>&1
  status=$?
  echo "exit $status secs $(( $(date +%s) - start ))" >> /home/user/oss/logs/osm-$s.log
  [ $s = s5 ] && git checkout -q -- app/controllers/notes_controller.rb
  mkdir -p $D/$s && cp tmp/lowrail-profile-$s/report.json tmp/lowrail-profile-$s/command.txt $D/$s/ 2>/dev/null
  echo "$s exit $status secs $(( $(date +%s) - start ))" >> /home/user/oss/logs/osm-serial.txt
done
