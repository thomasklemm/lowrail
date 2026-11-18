#!/bin/bash
# Lobsters YAML (11804786) vs DSL (current main), objects only, own Rails and c48c154e3f.
RAILS=c48c154e3f5285cb2fe4cf03b2e3a62cfd34ffc8
cd ~/lowrail-base
mise exec ruby@4.0.7 -- script/census app ~/apps/lobsters --name lobsters-yml --workloads ~/lowrail-base/fixtures/census-app/lobsters.yml --prepare ~/lowrail-base/fixtures/census-app/lobsters_prepare.rb --rails $RAILS --no-cpu > /tmp/rerun/lob-yml.log 2>&1
echo "yml exit $? $(date -u +%T)" >> /tmp/rerun/lob.done
cd /home/user/workspace/repo
mise exec ruby@4.0.7 -- script/census app ~/apps/lobsters --name lobsters-rb --workloads fixtures/census-app/lobsters.rb --prepare fixtures/census-app/lobsters_prepare.rb --rails $RAILS --no-cpu > /tmp/rerun/lob-rb.log 2>&1
echo "rb exit $? $(date -u +%T)" >> /tmp/rerun/lob.done
