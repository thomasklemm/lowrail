#!/usr/bin/env bash
set -e
d=$(dirname "$0")
# Master's bundled prism is labeled 1.9.0 but is ruby/prism 0616b251 (no MissingNode, which refract 1.1.0 needs),
# so Bundler treats the lock's prism 1.9.0 as installed; vendor the released 1.9.0, unchanged.
bash "$d/vendor-c-gem.sh" prism 1.9.0 - ext/prism prism/prism.so "released 1.9.0, not master's bundled copy"
