#!/usr/bin/env bash
# fresh-app.sh RUBY RAILS DIR : rails new (Minitest), a scaffold, a job and a mailer, the built gem in the Gemfile.
set -euo pipefail
ruby=$1 rails=$2 dir=$3
. "$(dirname "$0")/env.sh" "$ruby"
gem list -i lowrail-profile -v 0.1.0.rc1 >/dev/null || gem install --local --no-document "$GEMFILE_GEM"
mkdir -p "$(dirname "$dir")"; cd "$(dirname "$dir")"
rails "_${rails}_" new "$(basename "$dir")" --skip-kamal --skip-thruster --skip-docker --skip-ci --skip-rubocop --skip-brakeman --skip-bundler-audit --skip-system-test >/tmp/pr/new-$(basename "$dir")-$ruby.log 2>&1
cd "$dir"
bin/rails g scaffold Article title:string body:text >/dev/null
bin/rails g job Touch >/dev/null
bin/rails g mailer Notice hello >/dev/null
bin/rails db:migrate >/dev/null 2>&1
printf '\ngem "lowrail-profile", group: [:development, :test], require: false\n' >> Gemfile
bundle install >/dev/null
git add -A && git -c user.name=x -c user.email=x@x commit -qm base
bin/rails test 2>&1 | tail -3
