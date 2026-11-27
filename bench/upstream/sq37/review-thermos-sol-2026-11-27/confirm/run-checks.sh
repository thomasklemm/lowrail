#!/usr/bin/env bash
set -euxo pipefail
r=.amp/in/orb-backup/sq37-review/rails
out=bench/upstream/sq37/review-thermos-sol-2026-11-27/confirm
scratch=.amp/in/orb-backup/sq37-review/confirm
base=088fc0cf61e4ba0c7987decafacc69adb3e22eec
old=3e348f32bdc2b5b405d31f226e6de04aa3278dc9
head=e7a17ff01bab93970dd7fe3fe1ef7b9075dd6af2
mkdir -p "$scratch"
date -u --iso-8601=seconds
git rev-parse HEAD
git -C "$r" fetch --quiet https://github.com/thomasklemm/rails.git thomasklemm/sqlite-floor-3-37
test "$(git -C "$r" rev-parse FETCH_HEAD)" = "$head"
git -C "$r" fetch --quiet origin main
git -C "$r" rev-parse FETCH_HEAD
test "$(git -C "$r" rev-parse FETCH_HEAD)" = "$base"
test "$(git -C "$r" show -s --format=%P "$head")" = "$base"
test "$(git -C "$r" rev-list --count "$base..$head")" = 1
git -C "$r" show -s --format=fuller "$head"
git -C "$r" show -s --format='TRAILERS_BEGIN%n%(trailers:only)TRAILERS_END' "$head"
test -z "$(git -C "$r" show -s --format='%(trailers:only)' "$head")"
test "$(git -C "$r" show -s --format='%an <%ae>|%cn <%ce>' "$head")" = 'Thomas Klemm <github@tklemm.eu>|Thomas Klemm <github@tklemm.eu>'
git -C "$r" cat-file commit "$head" | sed '/^$/q'
git -C "$r" diff --check "$base" "$head"
git -C "$r" diff --stat "$old" "$head"
git -C "$r" diff "$old" "$head"
test "$(git -C "$r" diff --name-only "$old" "$head")" = activerecord/CHANGELOG.md
git -C "$r" diff --exit-code "$old" "$head" -- . ':!activerecord/CHANGELOG.md'
git -C "$r" range-diff "$base..$old" "$base..$head"
git -C "$r" diff "$base" "$head" -- activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb activerecord/test/cases/adapters/sqlite3/sqlite3_adapter_test.rb
git -C "$r" diff "$base" "$head" -- activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb activerecord/test/cases/adapters/sqlite3/sqlite3_adapter_test.rb | git patch-id --stable
git -C "$r" show "$head:activerecord/CHANGELOG.md" | sed -n '1,11p'
cp bench/upstream/pr-queue/items/SQ37.md "$out/reviewed-item.md"
cp bench/upstream/sq37/README.md "$out/reviewed-record.md"
python3 - <<'PY'
from pathlib import Path
import re
import subprocess

root = Path('bench/upstream/sq37/review-thermos-sol-2026-11-27')
item = (root / 'confirm/reviewed-item.md').read_text()
record = (root / 'confirm/reviewed-record.md').read_text()
posted = item.split('\n# ', 1)[1].split('\n## For Thomas', 1)[0].strip()
title, body = posted.split('\n\n', 1)
previous = (root / 'README.md').read_text()
proposal = re.search(r'(?m)^> Since #52354.*\n>\n> Raise .*$', previous).group(0)
expected = '\n'.join(line.removeprefix('>').removeprefix(' ') for line in proposal.splitlines())
assert body == expected, 'Body differs from the reviewed two-paragraph replacement'
head = 'e7a17ff01bab93970dd7fe3fe1ef7b9075dd6af2'
assert f'head: "{head}"' in item
subject = subprocess.check_output(['git', '-C', '.amp/in/orb-backup/sq37-review/rails', 'show', '-s', '--format=%s', head], text=True).strip()
assert title == subject
assert len(body.split('\n\n')) == 2
assert '#58284 (unreleased)' in body
assert 'Raw SQL and model operations using a preloaded schema cache can still work on these versions; this change refuses those connections too.' in body
assert 'model CRUD with a preloaded schema cache and cache-version checking disabled can still work; the new floor refuses those connections too.' in item.split('## For Thomas', 1)[1]
disclosure = record.split('## Disclosure fix (2026-11-27)', 1)[1]
assert 'check_schema_cache_dump_version = false' in disclosure
assert 'The `Model.create!` / `find` row above is the uncached case.' in disclosure
assert '`e7a17ff01b` keeps the code and test' in disclosure
print('BODY_VERBATIM_MATCH=true; title matches subject; two paragraphs; unreleased and compatibility disclosures present')
print('POSTED_TITLE_AND_BODY_BEGIN\n' + title + '\n\n' + body + '\nPOSTED_TITLE_AND_BODY_END')
print('PERMALINKS=' + '\n'.join(re.findall(r'https://github.com/[^)]+', body)))
PY
for spec in 'sqlite3/schema_statements.rb 218 227 schema_statements.rb' 'sqlite3_adapter.rb 518 522 sqlite3_adapter.rb'; do
  read -r path first last local_name <<< "$spec"
  path="activerecord/lib/active_record/connection_adapters/$path"
  gh api "repos/rails/rails/contents/$path?ref=$base" --jq .content | base64 -d > "$scratch/$local_name"
  cmp "$scratch/$local_name" <(git -C "$r" show "$base:$path")
  nl -ba "$scratch/$local_name" | sed -n "${first},${last}p"
done
for n in 52354 58284; do
  gh api "repos/rails/rails/pulls/$n" --jq '{number,title,state,merged_at,merge_commit_sha,base:.base.ref}'
done
git -C "$r" merge-base --is-ancestor 534b4ab2a65048c5eb558af2ef8ddcd93ff8d88d v8.0.0
gh api repos/rails/rails/releases/latest --jq '{tag_name,published_at}'
git -C "$r" show v8.1.4.1:activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb | sed -n '/def check_version/,/^      end/p'
if git -C "$r" merge-base --is-ancestor f652cc1648b954d546cfafb8ec4436ff9ff513ca v8.1.4.1; then
  echo 'Unexpected: prior floor bump is in the latest release'
  exit 1
else
  echo 'Prior floor bump is not in latest release v8.1.4.1'
fi
curl -fsSL --max-time 30 https://www.sqlite.org/releaselog/3_37_0.html
curl -fsSL --max-time 30 https://rubygems.org/api/v1/gems/sqlite3.json | jq '{name,version,downloads,version_created_at,source_code_uri}'
gh api repos/sparklemotion/sqlite3-ruby/contents/dependencies.yml?ref=v2.10.2 --jq .content | base64 -d
gh api repos/sparklemotion/sqlite3-ruby/contents/INSTALLATION.md?ref=v2.10.2 --jq .content | base64 -d
for repo in rails/rails sqlite/sqlite sparklemotion/sqlite3-ruby; do
  gh api "repos/$repo" --jq '{full_name,stargazers_count,archived,pushed_at,default_branch}'
done
gh api --method GET search/issues -f 'q=repo:rails/rails is:pr is:merged merged:>=2026-11-25 sqlite' -f per_page=100 --jq '{total_count,incomplete_results,items:[.items[]|{number,title,html_url}]}'
echo 'CONFIRMATION_CHECKS_COMPLETED'
