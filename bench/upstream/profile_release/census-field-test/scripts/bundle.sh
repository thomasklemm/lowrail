#!/usr/bin/env bash
# bundle.sh DIR RUBY: frozen bundle install of an app copy with its own Ruby (GCC 14 allowance for old C gems).
dir=$1 v=$2
export PATH="$(~/.local/bin/mise where ruby@$v)/bin:$PATH"; unset RUBYLIB RUBYOPT
CF="-Wno-error=incompatible-pointer-types"
export BUNDLE_BUILD__STRINGIO="--with-cflags=$CF"
cd "$dir" && BUNDLE_FROZEN=true bundle install --jobs 4 --quiet
