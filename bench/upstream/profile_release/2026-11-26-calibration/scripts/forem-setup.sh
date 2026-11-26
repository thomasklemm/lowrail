#!/usr/bin/env bash
# Forem setup as the OSS sweep (T-01a2142b) did it.
set -eux
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq postgresql-17-pgvector
sudo -u postgres psql -c "alter role postgres password 'postgres'"
~/.local/bin/mise install node@22
N=$(~/.local/bin/mise where node@22)
corepack enable --install-directory $N/bin || $N/bin/corepack enable --install-directory $N/bin
export PATH=$HOME/.local/share/mise/installs/ruby/3.3.14/bin:$N/bin:$PATH
export RAILS_ENV=test DATABASE_URL_TEST=postgres://postgres:postgres@localhost:5432/Forem_test REDIS_URL=redis://localhost:6379
cd ~/oss/forem
cp .env_sample .env
gem install --local /home/user/cal/gem/lowrail-profile-0.1.0.rc1.gem --no-document
echo 'gem "lowrail-profile", group: [:development, :test], require: false' >> Gemfile
bundle install -j8
git -c user.name=cal -c user.email=cal@local commit -qam "lowrail-profile Gemfile line"
git checkout HEAD~1 -- vendor/cache/
git add vendor/cache/lowrail-profile-0.1.0.rc1.gem
git -c user.name=cal -c user.email=cal@local commit -q --amend --no-edit
git show --stat HEAD | tail -5
bundle exec rails db:create db:schema:load
yarn install --immutable
SKIP_YARN_INSTALL=true bundle exec rails assets:precompile
git status --short | head
echo SETUP DONE
