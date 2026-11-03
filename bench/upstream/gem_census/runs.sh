#!/usr/bin/env bash
# Census runs for docs/upstream/gem-census.md, after `g`/`g2` (the A/A pair on
# census 5's ten and the PG census's nine configurations, set up on 5810776eec).
# The four L6 apps were set up on the pin itself, so script/census runs them as
# a second group under the same labels.
set -euo pipefail
cd "$(dirname "$0")/../../.."
pin=rails/rails@3bdc57909066eb17dee70fea0b6266edaffa9ffc
group1=blog,campfire,writebook,fizzy,fizzy-mysql,codetriage,pingcrm,redprints-cfp,react-starter-kit,lobsters,docuseal,mastodon,mastodon-nops,lago,lago-nops,discourse,loomio,sure,casa
group2=thinkroom,hackatime,flow,chatwoot
# connection_pool 3.x only: Chatwoot, Discourse, Lago and Sure lock 2.5.5 (Lago and Sure require < 3).
cp1=blog,campfire,writebook,fizzy,fizzy-mysql,codetriage,pingcrm,redprints-cfp,react-starter-kit,lobsters,docuseal,mastodon,mastodon-nops,loomio,casa
cp2=thinkroom,hackatime,flow
run() { script/census run --rails "$pin" --modes interp,yjit --jobs "${JOBS:-6}" "$@"; }
[[ ${SKIP_L6:-0} == 1 ]] || run --label g --aa --apps "$group2"
for spec in i1:thomasklemm/i18n@a9de2f70715591b68ee1dba6d79abe049ab93820 \
            i2:thomasklemm/i18n@568d730577748f4d1210ac13c5fe7fc167005f59; do
  label=${spec%%:*}
  run --label "$label" --gem "i18n=${spec#*:}" --apps "$group1"
  run --label "$label" --gem "i18n=${spec#*:}" --apps "$group2"
done
for spec in cpbase:mperham/connection_pool@5a3d762481b9ec46b7cfdf643f8597bd3fc5f02d \
            cp:thomasklemm/connection_pool@1533388d0749bbc30d76021a47d95e4e2a6941de; do
  label=${spec%%:*}
  run --label "$label" --gem "connection_pool=${spec#*:}" --apps "$cp1"
  run --label "$label" --gem "connection_pool=${spec#*:}" --apps "$cp2"
done
