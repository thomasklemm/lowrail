#!/usr/bin/env bash
set -e
d=$(dirname "$0")
# tokenizers 0.6.4 is the last release discourse_ai-tokenizers (~> 0.6.3) allows; its magnus 0.8.2 does not build
# on master. ankane/tokenizers-ruby master (0.7.x, magnus 0.9) builds, but is outside that requirement.
bash "$d/vendor-cargo-gem.sh" tokenizers 0.6.4 tokenizers/tokenizers.so
