#!/bin/bash
# dspec.sh GEMFILE TAG SEED : Decidim's GraphQL specs (each module's spec/types, decidim-api, API query extensions)
cd /home/user/w/gems/decidim
. /tmp/gqscripts/denv.sh
export BUNDLE_GEMFILE=$PWD/$1
mkdir -p /tmp/dspec/$2
: > /tmp/dspec/$2.log
for m in decidim-*; do
  files=$( (find $m/spec/types -name '*_spec.rb' 2>/dev/null; [ $m = decidim-api ] && find $m/spec -name '*_spec.rb' -not -path '*/system/*'; find $m/spec/lib -name 'query_extensions_spec.rb' 2>/dev/null; [ $m = decidim-core ] && find $m/spec/lib/api -name '*_spec.rb') | sort -u | sed "s|^$m/||")
  [ -z "$files" ] && continue
  (cd $m && mise exec ruby@4.0.9 -- bundle exec rspec $files --seed $3 -f progress -f json -o /tmp/dspec/$2/$m.json >> /tmp/dspec/$2.log 2>&1; echo "$m EXIT $?" >> /tmp/dspec/$2.log)
done
echo ALLDONE >> /tmp/dspec/$2.log
