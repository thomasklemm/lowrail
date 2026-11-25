#!/usr/bin/env bash
# gem.sh NAME REPO REF CMD...  census 11 gem sweep: clone REPO@REF twice (81, main), run CMD in each
# through bench/upstream/ecosystem/eco.sh, logs under ~/src/eco/logs/NAME-{81,main}[-RUN].log.
# GEM_ENV (space-separated K=V) is exported for both runs; GEM_SUB runs in that subdirectory.
# GEM_UNPIN=1 relaxes "< 8.2"/"~> 8.1" Rails caps in *.gemspec and Gemfile (both trees, so they match).
set -u
name=$1 repo=$2 ref=$3; shift 3
root=$HOME/src/eco/gems eco=/home/user/workspace/repo/bench/upstream/ecosystem/eco.sh
logs=$HOME/src/eco/logs run=${RUN:-1}
mkdir -p "$root" "$logs"
src=$root/$name-src
[ -d "$src" ] || git clone -q --filter=blob:none "https://github.com/$repo.git" "$src"
if [ "$ref" = latest ]; then
  ref=$(git -C "$src" tag --sort=-v:refname | rg -v -i 'rc|beta|alpha|pre' | head -1)
fi
git -C "$src" checkout -q "$ref" || exit 9
for label in 81 main; do
  dir=$root/$name-$label
  if [ ! -d "$dir" ]; then
    cp -a "$src" "$dir"
    if [ "${GEM_UNPIN:-0}" = 1 ]; then
      find "$dir" -maxdepth 2 \( -name '*.gemspec' -o -name Gemfile \) -print0 | xargs -0 sed -i -E \
        -e 's/(["'"'"'](active[a-z]+|action[a-z]+|railties|rails)["'"'"'][^#]*)["'"'"']\s*<\s*8\.2[^"'"'"']*["'"'"']/\1">= 0"/' \
        -e 's/(["'"'"'](active[a-z]+|action[a-z]+|railties|rails)["'"'"'][^#]*)["'"'"']\s*~>\s*8\.1[^"'"'"']*["'"'"']/\1">= 0"/'
    fi
  fi
  # eco.sh starts main's lock from 8-1's, so the two bundles differ only where Rails main requires it.
  [ "$label" = main ] && [ -f "$root/$name-81/${GEM_SUB:-.}/Gemfile.eco-81.lock" ] &&
    cp -n "$root/$name-81/${GEM_SUB:-.}/Gemfile.eco-81.lock" "$dir/${GEM_SUB:-.}/"
  log=$logs/$name-$label$([ "$run" = 1 ] || echo "-$run").log
  (
    cd "$dir/${GEM_SUB:-.}"
    for kv in ${GEM_ENV:-}; do export "$kv"; done
    export RAILS_ENV=${RAILS_ENV:-test} TESTOPTS=${TESTOPTS:---seed=4242} SPEC_OPTS=${SPEC_OPTS:---seed 4242}
    echo "== $name $label $(git -C "$src" rev-parse --short HEAD) $(date -u +%T)"
    timeout ${GEM_TIMEOUT:-1800} "$eco" . "$label" "$@"
    echo "== exit $? $(date -u +%T)"
  ) > "$log" 2>&1
done
