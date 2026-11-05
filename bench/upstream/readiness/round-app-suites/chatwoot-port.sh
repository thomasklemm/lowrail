#!/bin/bash
# Chatwoot's port to Rails 8.x from docs/upstream/app-suites.md (Chatwoot), applied to both trees. Gem changes are
# bumps in the manifest; this does the code edits. Community edition, as in Chatwoot's CI.
set -euo pipefail
rm -rf enterprise spec/enterprise
# Keyword-argument enum calls, removed in 8.0.
{ grep -rlE "^\s*enum [a-z_]+:" app lib || true; } | xargs -r sed -i -E 's/^(\s*)enum ([a-z_]+): /\1enum :\2, /'
# 8.1 raises on :index for a singular resource; the same routes.
sed -i 's/resource :app, only: \[:index\] do/resource :app, only: [] do/' config/routes.rb
# The latest administrate-field-belongs_to_search caps rails < 8.0 and administrate < 1.0.
gem() { mise exec ruby@${ECO_RUBY:-4.0.9} -- gem "$@"; }
v=administrate-field-belongs_to_search-0.10.0
if [ ! -d vendor-gems/$v ]; then
  tmp=$(mktemp -d) && (cd $tmp && gem fetch administrate-field-belongs_to_search -v 0.10.0 >/dev/null)
  gem unpack $tmp/$v.gem --target vendor-gems >/dev/null && gem spec $tmp/$v.gem --ruby > vendor-gems/$v/administrate-field-belongs_to_search.gemspec
  rm -rf $tmp
fi
sed -i 's/">= 0.3".freeze, "< 1.0".freeze/">= 0.3".freeze, "< 2.0".freeze/; s/">= 4.2".freeze, "< 8.0".freeze/">= 4.2".freeze/' vendor-gems/$v/administrate-field-belongs_to_search.gemspec
cp .env.example .env
