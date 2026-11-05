#!/bin/bash
# zspec.sh VARIANT(Gemfile|Gemfile.gqmaster|...) TAG SEED
cd /home/user/w/gems/zammad
. /tmp/gqscripts/zenv.sh
unset DATABASE_URL
export BUNDLE_GEMFILE=$PWD/$1
mkdir -p /tmp/zspec
mise exec ruby@4.0.9 -- bundle exec rspec spec/graphql -t ~searchindex -t ~integration -t ~required_envs --seed $3 -f progress -f json -o /tmp/zspec/$2.json > /tmp/zspec/$2.log 2>&1
echo "EXIT $?" >> /tmp/zspec/$2.log
