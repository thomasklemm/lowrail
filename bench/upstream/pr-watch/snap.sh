#!/bin/bash
# Usage: snap.sh OUT.json  — snapshot of thomasklemm's open upstream PRs (+ closed in last 2 days)
set -u; out=$1; tmp=$(mktemp -d)
W=${PRW:-$(cd "$(dirname "$0")" && pwd)}  # watch dir (state.json, watch.txt, issues.txt, exclude*.txt); PRW overrides
q() { gh api "search/issues?q=author:thomasklemm+is:pr+$1&per_page=100" --jq '.items[] | .html_url' ; }
# updated:, not closed: the search index can lag on closed_at (missed rails#59808, closed 11-14 23:54)
{ q "is:open"; q "is:closed+updated:>=$(date -u -d '-2 days' +%F)"; } \
  | grep -v -e 'github.com/argos-ri/' -e 'github.com/thomasklemm/' > "$tmp/urls0"
# keep PRs that were open in the last snapshot, so a close is seen even if search misses it
jq -r 'to_entries[]|select((.key|test("^https://github.com/.*/pull/")) and .value.state=="open")|.key' $W/state.json 2>/dev/null >> "$tmp/urls0"
grep -v "^#" $W/watch.txt >> "$tmp/urls0"
cat $W/exclude.txt $W/exclude.local.txt 2>/dev/null | grep -v "^\s*$" > "$tmp/excl"
grep -v -F -f "$tmp/excl" "$tmp/urls0" | sort -u > "$tmp/urls"
one() { url=$1
  r=$(echo "$url" | sed -E 's#https://github.com/([^/]+/[^/]+)/pull/([0-9]+)#\1 \2#'); set -- $r; repo=$1; n=$2
  p=$(gh api "repos/$repo/pulls/$n") || return 0
  sha=$(jq -r .head.sha <<<"$p")
  com=$(gh api "repos/$repo/issues/$n/comments?per_page=100" --jq '[.[]|select(.user.login!="thomasklemm")|{u:.user.login,id:.id,t:.created_at,b:(.body[0:200])}]')
  rev=$(gh api "repos/$repo/pulls/$n/reviews?per_page=100" --jq '[.[]|select(.user.login!="thomasklemm")|{u:.user.login,id:.id,s:.state,t:.submitted_at,b:(.body[0:200])}]')
  rc=$(gh api "repos/$repo/pulls/$n/comments?per_page=100" --jq '[.[]|select(.user.login!="thomasklemm")|{u:.user.login,id:.id,t:.created_at,path:.path,b:(.body[0:200])}]')
  cm=$(gh api "repos/$repo/pulls/$n/commits?per_page=100" --jq '[.[]|select((.author.login // .commit.author.name)!="thomasklemm" and .commit.author.email!="github@tklemm.eu")|{sha:.sha[0:10],a:(.author.login // .commit.author.name),m:(.commit.message|split("\n")[0])}]')
  st=$(gh api "repos/$repo/commits/$sha/status" --jq '{state, s:[.statuses[]|select(.state!="success")|{c:.context,s:.state,u:.target_url}]}')
  ck=$(gh api "repos/$repo/commits/$sha/check-runs?per_page=100" --jq '{total:.total_count, bad:[.check_runs[]|select(.conclusion!="success" and .conclusion!="skipped" and .conclusion!="neutral")|{n:.name,s:.status,c:.conclusion}]}' 2>/dev/null || echo '{}')
  jq -n --arg url "$url" --argjson p "$p" --argjson com "$com" --argjson rev "$rev" --argjson rc "$rc" --argjson cm "$cm" --argjson st "$st" --argjson ck "$ck" \
    '{key:$url, value:{state:$p.state, merged:$p.merged, merged_by:$p.merged_by.login, merged_at:$p.merged_at, merge_sha:$p.merge_commit_sha, closed_at:$p.closed_at, draft:$p.draft, mstate:$p.mergeable_state, head:$p.head.sha, branch:$p.head.ref, title:$p.title, com:$com, rev:$rev, rc:$rc, cm:$cm, status:$st, checks:$ck}}' > "$TMPD/$(echo "$url" | md5sum | cut -c1-12).json"
}
export -f one; export TMPD=$tmp
xargs -P 8 -I{} bash -c 'one "$@"' _ {} < "$tmp/urls"
cat "$tmp"/*.json | jq -s 'from_entries' > "$out"
rm -rf "$tmp"; echo "prs=$(jq length "$out")"
# Report-only issues (issues.txt): state, labels, comments by others
while read -r i; do
  gh api "repos/$i" --jq '{key:"https://github.com/'"$i"'", value:{state, closed_at, closed_by:.closed_by.login, labels:[.labels[].name]}}'
done < $W/issues.txt | jq -s from_entries > /tmp/iss.json
for i in $(cat $W/issues.txt); do
  gh api "repos/$i/comments?per_page=100" --jq '{key:"https://github.com/'"$i"'", value:[.[]|select(.user.login!="thomasklemm")|{u:.user.login,a:.author_association,id:.id,t:.created_at,b:(.body[0:200])}]}'
done | jq -s from_entries > /tmp/iss-com.json
jq --slurpfile i /tmp/iss.json --slurpfile c /tmp/iss-com.json '. + ($i[0] | with_entries(.value.com = $c[0][.key]))' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
# Foreign PR rails/rails#57785 (Halvanhelv): track only merge/close and head (new push).
p=$(gh api repos/rails/rails/pulls/57785)
jq --argjson p "$p" '.["foreign:rails/rails/pull/57785"] = {state:$p.state, merged:$p.merged, merged_by:$p.merged_by.login, closed_at:$p.closed_at, head:$p.head.sha}' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
# Foreign PR rails/rails#59631 (MIbtehajNasar, fixes our issue): our review 5775467814 at 2026-11-04T20:42:23Z. Track state, head, later comments/reviews/review comments by others.
T=2026-11-04T20:42:23Z
p=$(gh api repos/rails/rails/pulls/59631)
com=$(gh api "repos/rails/rails/issues/59631/comments?per_page=100" --jq "[.[]|select(.user.login!=\"thomasklemm\" and .created_at>\"$T\")|{u:.user.login,id:.id,t:.created_at,b:(.body[0:200])}]")
rev=$(gh api "repos/rails/rails/pulls/59631/reviews?per_page=100" --jq "[.[]|select(.user.login!=\"thomasklemm\" and (.submitted_at//\"\")>\"$T\")|{u:.user.login,id:.id,s:.state,t:.submitted_at,b:(.body[0:200])}]")
rc=$(gh api "repos/rails/rails/pulls/59631/comments?per_page=100" --jq "[.[]|select(.user.login!=\"thomasklemm\" and .created_at>\"$T\")|{u:.user.login,id:.id,t:.created_at,path:.path,b:(.body[0:200])}]")
jq --argjson p "$p" --argjson com "$com" --argjson rev "$rev" --argjson rc "$rc" \
  '.["foreign:rails/rails/pull/59631"] = {state:$p.state, merged:$p.merged, merged_by:$p.merged_by.login, closed_at:$p.closed_at, head:$p.head.sha, com:$com, rev:$rev, rc:$rc}' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
# Foreign PR rails/rails#57057 (matthewd, merged): our heads-up comment 6642150088 at 2026-11-04T21:08:07Z. Track later comments/reviews by others and cross-references (follow-up PRs/issues).
T=2026-11-04T21:08:07Z
com=$(gh api "repos/rails/rails/issues/57057/comments?per_page=100" --paginate --jq "[.[]|select(.user.login!=\"thomasklemm\" and .created_at>\"$T\")|{u:.user.login,id:.id,t:.created_at,b:(.body[0:200])}]" | jq -s add)
rev=$(gh api "repos/rails/rails/pulls/57057/reviews?per_page=100" --jq "[.[]|select(.user.login!=\"thomasklemm\" and (.submitted_at//\"\")>\"$T\")|{u:.user.login,id:.id,s:.state,t:.submitted_at,b:(.body[0:200])}]")
xr=$(gh api "repos/rails/rails/issues/57057/timeline?per_page=100" --paginate --jq '[.[]|select(.event=="cross-referenced")|{id:.source.issue.html_url,u:.actor.login,t:.created_at,b:("linked from "+.source.issue.html_url+" "+.source.issue.title)}]' | jq -s add)
jq --argjson com "$com" --argjson rev "$rev" --argjson xr "$xr" '.["foreign:rails/rails/pull/57057"] = {com:($com + $xr), rev:$rev}' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
# Foreign PR ruby/ruby#17251 (eightbitraptor): our re-test answer 6652543942 at 2026-11-05T07:41:03Z. Track state, draft, head, later comments/reviews/review comments by others. Our 11-14 comment 6882169535 was deleted; its numbers are now an "Update 2026-11-14" in 6652543942 (edited 2026-11-14T19:07Z).
T=2026-11-05T07:41:03Z
p=$(gh api repos/ruby/ruby/pulls/17251)
com=$(gh api "repos/ruby/ruby/issues/17251/comments?per_page=100&since=$T" --jq "[.[]|select(.user.login!=\"thomasklemm\" and .created_at>\"$T\")|{u:.user.login,id:.id,t:.created_at,b:(.body[0:200])}]")
rev=$(gh api "repos/ruby/ruby/pulls/17251/reviews?per_page=100" --jq "[.[]|select(.user.login!=\"thomasklemm\" and (.submitted_at//\"\")>\"$T\")|{u:.user.login,id:.id,s:.state,t:.submitted_at,b:(.body[0:200])}]")
rc=$(gh api "repos/ruby/ruby/pulls/17251/comments?per_page=100&since=$T" --jq "[.[]|select(.user.login!=\"thomasklemm\" and .created_at>\"$T\")|{u:.user.login,id:.id,t:.created_at,path:.path,b:(.body[0:200])}]")
jq --argjson p "$p" --argjson com "$com" --argjson rev "$rev" --argjson rc "$rc" \
  '.["foreign:ruby/ruby/pull/17251"] = {state:$p.state, merged:$p.merged, merged_by:$p.merged_by.login, closed_at:$p.closed_at, draft:$p.draft, head:$p.head.sha, com:$com, rev:$rev, rc:$rc}' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
# Generic foreign PR watcher: foreign REPO N SINCE -> state, head, comments/reviews/review comments by others after SINCE
foreign() { local repo=$1 n=$2 T=$3 p com rev rc
p=$(gh api repos/$repo/pulls/$n)
com=$(gh api "repos/$repo/issues/$n/comments?per_page=100&since=$T" --jq "[.[]|select(.user.login!=\"thomasklemm\" and .created_at>\"$T\")|{u:.user.login,id:.id,t:.created_at,b:(.body[0:200])}]")
rev=$(gh api "repos/$repo/pulls/$n/reviews?per_page=100" --jq "[.[]|select(.user.login!=\"thomasklemm\" and (.submitted_at//\"\")>\"$T\")|{u:.user.login,id:.id,s:.state,t:.submitted_at,b:(.body[0:200])}]")
rc=$(gh api "repos/$repo/pulls/$n/comments?per_page=100&since=$T" --jq "[.[]|select(.user.login!=\"thomasklemm\" and .created_at>\"$T\")|{u:.user.login,id:.id,t:.created_at,path:.path,b:(.body[0:200])}]")
jq --arg k "foreign:$repo/pull/$n" --argjson p "$p" --argjson com "$com" --argjson rev "$rev" --argjson rc "$rc" \
  '.[$k] = {state:$p.state, merged:$p.merged, merged_by:$p.merged_by.login, closed_at:$p.closed_at, head:$p.head.sha, com:$com, rev:$rev, rc:$rc}' "$out" > "$out.tmp" && mv "$out.tmp" "$out"; }
foreign rails/rails 58483 2026-11-05T11:09:54Z
foreign rails/rails 59500 2026-11-05T10:50:59Z
# ruby/ruby#16909 (Earlopain, closed): our Thomas-approved reply 7222359284 (2026-11-27T15:41:13Z); report any reply by others (nobu, hsbt, eregon)
foreign ruby/ruby 16909 2026-11-27T15:41:13Z
# with_advisory_lock latest version on rubygems (report a fix release for issue 149)
v=$(curl -s https://rubygems.org/api/v1/versions/with_advisory_lock/latest.json | jq -r .version)
[ -n "$v" ] && [ "$v" != null ] && jq --arg v "$v" '.["gem:with_advisory_lock"] = {version:$v}' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
# Fork runs on thomasklemm/ruby-bench that gate draft notes (report conclusions)
for id in 42079217004 42081299470 42079221738; do
  r=$(gh api repos/thomasklemm/ruby-bench/actions/runs/$id --jq '{status,conclusion,branch:.head_branch}') || continue
  jq --arg k "run:thomasklemm/ruby-bench/$id" --argjson r "$r" '.[$k] = $r' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
done
# Repo watch gshutler/useragent (held UA1 waits for any maintainer act): master, gem version, gshutler comments/reviews, merged/closed PRs, #73
r=gshutler/useragent
uv=$(jq -n \
  --arg m "$(gh api repos/$r/commits/master --jq .sha[0:10])" \
  --arg g "$(curl -s https://rubygems.org/api/v1/versions/useragent/latest.json | jq -r .version)" \
  --arg c "$(gh api "repos/$r/issues/comments?sort=created&direction=desc&per_page=100" --jq '[.[]|select(.user.login=="gshutler")|.id]|max')" \
  --arg rc "$(gh api "repos/$r/pulls/comments?sort=created&direction=desc&per_page=100" --jq '[.[]|select(.user.login=="gshutler")|.id]|max')" \
  --arg cl "$(gh api "repos/$r/pulls?state=closed&sort=updated&direction=desc&per_page=1" --jq '.[0]|"\(.number) \(.closed_at) merged=\(.merged_at!=null)"')" \
  --arg p73 "$(gh api repos/$r/pulls/73 --jq '"\(.state) merged=\(.merged) reviews="' )$(gh api repos/$r/pulls/73/reviews --jq 'length')" \
  '{master:$m, gem:$g, gs_comment:$c, gs_review_comment:$rc, last_closed_pr:$cl, pr73:$p73}')
[ -n "$uv" ] && jq --argjson v "$uv" '.["repo:gshutler/useragent"] = $v' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
# Foreign PR ruby/ruby#18616 (tekknolagi, covers our ZJIT lead 15a): state, draft, head, push date, comments by others, no_side_exits lines in the diff
p=$(gh api repos/ruby/ruby/pulls/18616) && {
  nse=$(gh api repos/ruby/ruby/pulls/18616 -H 'Accept: application/vnd.github.diff' 2>/dev/null | grep -c no_side_exits)
  pd=$(gh api "repos/ruby/ruby/commits/$(jq -r .head.sha <<<"$p")" --jq .commit.committer.date)
  com=$(gh api "repos/ruby/ruby/issues/18616/comments?per_page=100" --jq '[.[]|select(.user.login!="thomasklemm")|{u:.user.login,id:.id,t:.created_at,b:(.body[0:200])}]')
  rev=$(gh api "repos/ruby/ruby/pulls/18616/reviews?per_page=100" --jq '[.[]|select(.user.login!="thomasklemm")|{u:.user.login,id:.id,s:.state,t:.submitted_at,b:(.body[0:200])}]')
  jq --argjson p "$p" --argjson com "$com" --argjson rev "$rev" --arg nse "$nse" --arg pd "$pd" \
    '.["foreign:ruby/ruby/pull/18616"] = {state:$p.state, merged:$p.merged, merged_by:$p.merged_by.login, closed_at:$p.closed_at, draft:$p.draft, head:$p.head.sha, pushed:$pd, nse:($nse|tonumber), com:$com, rev:$rev}' "$out" > "$out.tmp" && mv "$out.tmp" "$out"; }
