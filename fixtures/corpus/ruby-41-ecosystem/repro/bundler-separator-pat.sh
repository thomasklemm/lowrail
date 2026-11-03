#!/bin/bash
# Bundler <= 4.0.11 on Ruby 4.1 cannot install a path or git gem.
#   bundler-separator-pat.sh RUBYMASTER_BIN_DIR [BUNDLER_VERSION]
set -u
new=$1 v=${2:-2.6.9} dir=$(mktemp -d)
cd "$dir"
"$new/gem" install bundler -v "$v" --no-document -q > /dev/null 2>&1
mkdir -p local/lib && touch local/lib/local.rb
printf 'Gem::Specification.new { |s| s.name = "local"; s.version = "0.1"; s.summary = "x"; s.authors = ["x"]; s.files = ["lib/local.rb"] }\n' > local/local.gemspec
printf 'gem "local", path: "local"\n' > Gemfile
BUNDLE_PATH=vendor "$new/bundle" "_${v}_" install 2>&1 | grep -m1 -E 'SEPARATOR_PAT|Bundle complete'
