#!/usr/bin/env bash
set -e
mkdir -p /tmp/rb-dl
for v in 2.7.3 2.7.8 3.0.7 3.1.7 3.2.9 3.3.9 3.4.6; do
  d=/opt/hostedtoolcache/Ruby/$v/x64
  [ -x $d/bin/ruby ] && continue
  gh release download toolcache -R ruby/ruby-builder -p "ruby-$v-ubuntu-24.04.tar.gz" -D /tmp/rb-dl --clobber
  sudo mkdir -p $d && sudo tar -xzf /tmp/rb-dl/ruby-$v-ubuntu-24.04.tar.gz -C $d --strip-components=1 && sudo chown -R $(id -u) /opt/hostedtoolcache/Ruby/$v
  $d/bin/ruby -v
done
