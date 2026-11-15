#!/usr/bin/env bash
# Local replay of importmap-rails' CI matrix (.github/workflows/ci.yml) on one checkout.
# usage: ci_matrix.sh CHECKOUT LOG
dir=$1; log=$2; touch "$log"; sed -i "/^DONE$/d" "$log"
declare -A RB=([3.1]=/opt/hostedtoolcache/Ruby/3.1.7/x64/bin)
for v in 3.2 3.3 3.4 4.0; do RB[$v]="$(~/.local/bin/mise where ruby@$v)/bin"; done
excluded() { local r=$1 rails=$2 p=$3
  [[ $rails == 6.1 && $p == propshaft ]] && return 0
  [[ $r == 3.1 && ( $rails == 8.0 || $rails == 8.1 || $rails == main ) ]] && return 0
  [[ $r == 3.2 && $rails == main ]] && return 0
  [[ $r == 4.0 && $rails == 6.1 ]] && return 0
  [[ ( $rails == 8.0 || $rails == 8.1 || $rails == main ) && $p == sprockets ]] && return 0
  return 1; }
cd "$dir"
for r in 3.1 3.2 3.3 3.4 4.0; do for rails in 6.1 7.0 7.1 7.2 8.0 8.1 main; do for p in sprockets propshaft; do
  excluded $r $rails $p && continue
  grep -q "^Ruby $r, Rails $rails, $p:" "$log" && continue
  gf=gemfiles/rails_${rails}_${p}.gemfile; rm -f $gf.lock
  out=$(PATH="${RB[$r]}:$PATH" BUNDLE_GEMFILE=$gf ASSETS_PIPELINE=$p bash -c 'bundle install --quiet -j2 >/dev/null 2>&1 || bundle install 2>&1 | tail -5; bundle exec rake 2>&1' | grep -E "runs, .* assertions|Error|rror:|Failure" | tail -3)
  echo "Ruby $r, Rails $rails, $p: $out" >> "$log"
done; done; done
echo DONE >> "$log"
