#!/bin/bash
# Forem's JavaScript with Node 22 (Forem asks for >= 22.23.4 < 23) and its own Yarn release. Puts a `yarn` on
# tmp/readiness-bin for assets:precompile, which runs `yarn build` and `yarn postcss`.
set -euo pipefail
mkdir -p tmp/readiness-bin
printf '#!/bin/sh\nexec node %s/.yarn/releases/yarn-4.1.0.cjs "$@"\n' "$PWD" > tmp/readiness-bin/yarn
chmod +x tmp/readiness-bin/yarn
export PATH=$PWD/tmp/readiness-bin:$(mise where node@22)/bin:$PATH
CYPRESS_INSTALL_BINARY=0 yarn install --immutable
