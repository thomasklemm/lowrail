#!/usr/bin/env bash
# setup-gems.sh RUBY RAILS : CI's gem set for the profile suite, in that Ruby's own gem home.
set -euo pipefail
ruby=$1 rails=$2
bin="$(mise where ruby@$ruby)/bin"
export PATH="$bin:$PATH"
ruby -v
gem install --no-document rails -v "$rails"
gem install --no-document sqlite3 bcrypt minitest:5.27.0 rspec-core
gem list | grep -E '^(rails|minitest|rspec-core|sqlite3|bcrypt|bundler) '
