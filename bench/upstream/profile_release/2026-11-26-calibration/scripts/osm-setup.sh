#!/usr/bin/env bash
# openstreetmap-website setup as the OSS sweep (T-01a2142b) did it.
set -eux
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libarchive-dev libxml2-dev libxslt1-dev libgd-dev libyaml-dev libsqlite3-dev
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH RAILS_ENV=test OPENSTREETMAP_MEMCACHE_SERVERS=127.0.0.1
cd ~/oss/openstreetmap-website
cp config/github.database.yml config/database.yml
cp config/example.storage.yml config/storage.yml
gem install --local /home/user/cal/gem/lowrail-profile-0.1.0.rc1.gem --no-document
echo 'gem "lowrail-profile", group: [:development, :test], require: false' >> Gemfile
bundle install -j8
git -c user.name=cal -c user.email=cal@local commit -qam "lowrail-profile Gemfile line"
bin/yarn install
touch config/settings.local.yml
bundle exec rails db:create db:schema:load
bundle exec i18n export
bundle exec rails assets:precompile
mkdir -p tmp/pids
git status --short | head
echo SETUP DONE
