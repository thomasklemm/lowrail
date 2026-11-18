# A1: draft note for kamipo on #59836 (not posted)

For Thomas, in case he prefers handing the fix over instead of opening a PR. It follows the approved style for
comments on others' PRs ([DECISIONS](../../../docs/DECISIONS.md#no-comments-on-others-prs-without-thomass-approval-thomas-2026-11-04)).
Posting needs Thomas's approval of this exact text.

---

Heads-up in case it's useful: since #59825 and this PR, every association load and `joins(:assoc)` builds the
`WhereClause` differences for `keep_owner_conditions`, also when the association has no scope and nothing can
remove a condition. That is five `WhereClause#-` (ten objects) per `author.posts` load, and two for every join.

```ruby
class Author < ActiveRecord::Base
  has_many :posts
end

author.posts.reset
author.posts.to_a # 107 objects on main, 96 before #59825
```

Computing the differences only after a scope item was merged keeps the same SQL, records and deprecation
warnings: thomasklemm/rails@9877a852dd (+17/−10).

---

Record: [census 10, lead A1](../../../docs/upstream/rails-main-census-10.md#lead-a1-owner-condition-bookkeeping-on-every-association-scope),
numbers in [body/a1](body/a1/table.md); A/A per cell in the record.
