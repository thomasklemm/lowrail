# A1: draft note for kamipo on #59836 (not posted)

For Thomas, in case he prefers handing the fix over instead of opening a PR. Posting needs his approval of this
exact text ([DECISIONS](../../../docs/DECISIONS.md#no-comments-on-others-prs-without-thomass-approval-thomas-2026-11-04)).
The policy there says no numbers nobody asked for. The two lines of cost can be dropped if Thomas wants it to stay
within that policy.

---

Heads-up in case it's useful: `keep_owner_conditions` compares where clauses with `WhereClause#-` on every
association scope and join, also when the association has no scope. That is five differences per `author.posts`
load and three per `join_scope`. `Array#-` hashes both sides once each has more than 16 predicates, and
`QueryAttribute#hash` serializes the bind value, so binds are now serialized before the query is built. On 8.1 this
returns `[]`; on main it raises:

```ruby
class Child < ActiveRecord::Base
  default_scope { where((0..16).to_h { |i| [:"k#{i}", 1] }.merge(k0: 2**70)) } # integer columns k0..k16
end

class Parent < ActiveRecord::Base
  has_many :children
end

Parent.joins(:children).to_a # 8.1: [] (1=0); main: ActiveModel::RangeError
```

Custom types whose serialization depends on context see the same timing change. Two predicates on one column are
enough for that, because `QueryAttribute#==` serializes too.

Cost per load against 8.1 in our fixture (Callgrind, interpreter, Ruby 4.0.9): `author.posts` +3.6%, A/A 0.01%;
`joins(:posts)` +5.6%, A/A 0.01%. About half of it is these comparisons, 10 of 107 objects per load.

thomasklemm/rails@80daecf52a skips the comparisons when no scope was merged, and adds tests for the case above and
for a scope that changes how its keys serialize. When a scope was merged, the check still compares, after the scope
ran.

---

Record: [A1 follow-up](followup-81/README.md) (8.1 against main, repros), [A1](README.md),
[census 10 lead A1](../../../docs/upstream/rails-main-census-10.md#lead-a1-owner-condition-bookkeeping-on-every-association-scope).
