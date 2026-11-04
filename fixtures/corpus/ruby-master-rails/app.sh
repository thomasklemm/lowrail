#!/usr/bin/env bash
# usage: app.sh RUBY_BIN_DIR APP_DIR LOG
# Scaffold, migrate, test, precompile assets and boot a freshly generated app.
set -u
export PATH=$1:$PATH BUNDLE_PATH=$HOME/src/bundle
cd "$2" || exit 1
exec > "$3" 2>&1
step() { echo "== $*"; "$@"; echo "== exit=$?"; }
ruby -v
step bin/rails g scaffold Post title:string body:text published:boolean
step bin/rails db:migrate
step bin/rails test
step bin/rails test:system
step env RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
step env RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails db:prepare
step env RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner 'p Rails.application.eager_load!; p Post.count'
step bin/rails zeitwerk:check
bin/rails server -p ${APP_PORT:-3123} > log/server.out 2>&1 & pid=$!
for i in $(seq 1 60); do curl -fs -o /dev/null "http://localhost:${APP_PORT:-3123}/up" && break; sleep 1; done
for p in /up /posts /posts/new; do echo "GET $p $(curl -s -o /dev/null -w '%{http_code}' http://localhost:${APP_PORT:-3123}$p)"; done
tok=$(curl -s -c /tmp/cj.$$ http://localhost:${APP_PORT:-3123}/posts/new | grep -o 'name="authenticity_token" value="[^"]*"' | head -1 | sed 's/.*value="//;s/"$//')
echo "POST /posts $(curl -s -b /tmp/cj.$$ -o /dev/null -w '%{http_code}' --data-urlencode "authenticity_token=$tok" --data-urlencode 'post[title]=Hi' --data-urlencode 'post[body]=Body' http://localhost:${APP_PORT:-3123}/posts)"
echo "GET /assets $(curl -s -o /dev/null -w '%{http_code}' http://localhost:${APP_PORT:-3123}$(curl -s http://localhost:${APP_PORT:-3123}/posts | grep -o '/assets/application-[^"]*\.css' | head -1))"
kill $pid; wait $pid 2>/dev/null; rm -f /tmp/cj.$$
grep -i -E "error|exception|warning:" log/server.out log/development.log log/test.log | head -20
echo DONE
