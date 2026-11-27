#!/usr/bin/env bash
set -euxo pipefail
r=.amp/in/orb-backup/sq37-review/rails
for n in 52354 58284; do
  gh api "repos/rails/rails/pulls/$n" --jq '{number,title,state,merged_at,merge_commit_sha,base:.base.ref}'
  gh api --paginate "repos/rails/rails/pulls/$n/files" --jq '.[] | {filename,patch}'
done
git -C "$r" fetch --quiet origin tag v8.0.0
git -C "$r" show v8.0.0:activerecord/lib/active_record/connection_adapters/sqlite3/schema_statements.rb | nl -ba | sed -n '200,235p'
git -C "$r" merge-base --is-ancestor 534b4ab2a65048c5eb558af2ef8ddcd93ff8d88d v8.0.0
git -C "$r" show 088fc0cf61e4ba0c7987decafacc69adb3e22eec:activerecord/lib/active_record/connection_adapters/sqlite3/schema_statements.rb | nl -ba | sed -n '218,227p'
git -C "$r" show 088fc0cf61e4ba0c7987decafacc69adb3e22eec:activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb | nl -ba | sed -n '518,522p'
curl -fsSL https://www.sqlite.org/releaselog/3_37_0.html
curl -fsSL https://www.sqlite.org/pragma.html | sed -n '/<a name="pragma_table_list"/,/<a name="pragma_table_xinfo"/p'
for repo in rails/rails sparklemotion/sqlite3-ruby sqlite/sqlite; do
  gh api "repos/$repo" --jq '{full_name,stargazers_count,archived,pushed_at,default_branch,html_url}'
  gh api "repos/$repo/releases/latest" --jq '{tag_name,published_at,html_url}' || true
done
for gem in rails sqlite3; do
  curl -fsSL "https://rubygems.org/api/v1/gems/$gem.json" | jq '{name,version,downloads,version_downloads,version_created_at,source_code_uri,project_uri}'
done
curl -fsSL https://www.sqlite.org/changes.html | head -100 || test "${PIPESTATUS[0]}" -eq 23
gh api repos/sparklemotion/sqlite3-ruby/git/ref/tags/v2.10.2 --jq '{ref,object}'
gh api repos/sparklemotion/sqlite3-ruby/commits/v2.10.2 --jq '{sha,commit:{committer:.commit.committer,message:.commit.message}}'
gh api repos/sparklemotion/sqlite3-ruby/contents/INSTALLATION.md?ref=v2.10.2 --jq .content | base64 -d
gh api repos/sparklemotion/sqlite3-ruby/contents/dependencies.yml?ref=v2.10.2 --jq .content | base64 -d
gh api repos/sparklemotion/sqlite3-ruby/contents/INSTALLATION.md --jq .content | base64 -d
gh api repos/sparklemotion/sqlite3-ruby/contents/dependencies.yml --jq .content | base64 -d
for q in 'repo:rails/rails is:pr is:merged merged:>=2026-11-25' 'repo:rails/rails is:pr pragma_table_list' 'repo:rails/rails is:pr is:merged merged:>=2026-11-25 sqlite' 'repo:rails/rails is:pr is:open "check_version"' 'repo:rails/rails is:pr "3.37.0"'; do
  gh api --method GET search/issues -f "q=$q" -f per_page=100 --paginate --jq '{total_count,incomplete_results,items:[.items[] | {number,title,state,html_url}]}'
done
