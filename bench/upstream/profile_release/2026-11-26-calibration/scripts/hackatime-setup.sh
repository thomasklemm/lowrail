#!/usr/bin/env bash
# Hackatime setup as the census field test (T-01a2142d) did it: source-only corpus copy, own lock (Rails 8.1.3.1).
set -eux
export PATH=$(~/.local/bin/mise where ruby@4.0.6)/bin:$PATH
export CFLAGS="-Wno-error=incompatible-pointer-types -Wno-error=int-conversion -Wno-error=implicit-function-declaration"
export BUNDLE_BUILD__STRINGIO="--with-cflags=$CFLAGS"
cd /home/user/workspace/repo/.corpus/ft-hackatime
BUNDLE_FROZEN=true bundle install --jobs 4 --quiet
unset CFLAGS BUNDLE_BUILD__STRINGIO
export TEST_DATABASE_URL=postgres:///ft_hackatime_test
RAILS_ENV=test bin/rails db:create db:schema:load
echo SETUP DONE
