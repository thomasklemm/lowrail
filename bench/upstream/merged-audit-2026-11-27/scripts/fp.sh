#!/bin/bash
# usage: fp.sh owner repo number...
o=$1; r=$2; shift 2
for n in "$@"; do
gh api graphql -f query="query { repository(owner:\"$o\", name:\"$r\") { pullRequest(number:$n) { headRefOid timelineItems(first:100, itemTypes:[HEAD_REF_FORCE_PUSHED_EVENT, PULL_REQUEST_COMMIT, MERGED_EVENT]) { nodes { __typename ... on HeadRefForcePushedEvent { actor { login } createdAt beforeCommit { oid } afterCommit { oid } } ... on PullRequestCommit { commit { oid committer { name } author { name } } } ... on MergedEvent { actor { login } createdAt } } } } } }" --jq ".data.repository.pullRequest.timelineItems.nodes[] | select(.__typename==\"HeadRefForcePushedEvent\" or .__typename==\"MergedEvent\" or (.__typename==\"PullRequestCommit\" and .commit.committer.name != \"Thomas Klemm\")) | \"$n \" + (if .__typename==\"HeadRefForcePushedEvent\" then \"FP \(.actor.login) \(.createdAt) \(.beforeCommit.oid[0:10])->\(.afterCommit.oid[0:10])\" elif .__typename==\"MergedEvent\" then \"MERGED \(.actor.login) \(.createdAt)\" else \"COMMIT \(.commit.oid[0:10]) a=\(.commit.author.name) c=\(.commit.committer.name)\" end)"
done
