#!/bin/bash
# Bundler 4.0.x on Ruby 4.1 crashes on a .bundle/config that Bundler itself wrote.
#   bundler-empty-config.sh RUBY407_BIN_DIR RUBYMASTER_BIN_DIR
set -u
old=$1 new=$2 dir=$(mktemp -d)
cd "$dir"
printf 'source "https://rubygems.org"\n' > Gemfile
"$old/bundle" lock > /dev/null                       # BUNDLED WITH 4.0.x
"$old/bundle" config set --local foo bar > /dev/null
"$old/bundle" config unset --local foo               # leaves "---\n"
od -c .bundle/config | head -1
"$new/ruby" -e 'require "rubygems/yaml_serializer"; p Gem::YAMLSerializer.load("---\n")'  # nil (4.0.7: {})
"$new/bundle" config list 2>&1 | grep -m1 -E 'NoMethodError|Settings'   # 4.0.x is selected from BUNDLED WITH
