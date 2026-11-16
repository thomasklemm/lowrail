#!/usr/bin/env bash
# usage: gem_builds.sh — `gem install` of the C-extension gems that broke a census bundle on master, on r409 and master,
# each into a scratch GEM_HOME; prints ok or the first compiler error per gem.
here=$(cd "$(dirname "$0")" && pwd)
for l in r409 master; do (
  source "$here/env.sh" "$l"
  export GEM_HOME=$R3/gem-builds/$l; rm -rf "$GEM_HOME"; mkdir -p "$GEM_HOME"
  echo "== $l: $(ruby -v)"
  for g in bluecloth:2.2.0 rbtrace:0.5.4 rbtrace:0.5.5; do
    log=$GEM_HOME/${g/:/-}.log
    if gem install "${g%%:*}" -v "${g##*:}" --no-document >"$log" 2>&1; then echo "$g ok"
    else echo "$g FAILED: $(grep -m1 -E ' error: ' "$GEM_HOME"/extensions/*/*/${g/:/-}/gem_make.out "$log" 2>/dev/null | sed 's/^[^:]*://' | head -1)"; fi
  done
); done
