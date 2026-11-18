# A1: draft note for kamipo on #59836 (not posted)

For Thomas, in case he prefers handing the fix over instead of opening a PR. Posting needs his approval of this
exact text ([DECISIONS](../../../docs/DECISIONS.md#no-comments-on-others-prs-without-thomass-approval-thomas-2026-11-04)).
It contains no cost numbers, as that policy requires.

---

Heads-up in case it's useful: `join_scope` now compares where clauses with `WhereClause#-` also when the
association has no scope. `Array#-` hashes both sides once they are large enough, and `QueryAttribute#hash`
serializes the bind value, so this join raises on main and returns `[]` on 8.1:

```ruby
class Child < ActiveRecord::Base
  default_scope { where((0..16).to_h { |i| [:"k#{i}", 1] }.merge(k0: 2**70)) } # integer columns k0..k16
end

class Parent < ActiveRecord::Base
  has_many :children
end

Parent.joins(:children).to_a # 8.1: [] (1=0); main: ActiveModel::RangeError
```

thomasklemm/rails@e6bfe76e95 skips the comparison in `join_scope` when there are no scope items, with a test. The
association reader and scoped joins compare as on main; a scoped join that `unscope`s the bad condition still
raises.

---

Record: [narrowed A1](narrow/README.md), [A1](README.md),
[census 10 lead A1](../../../docs/upstream/rails-main-census-10.md#lead-a1-owner-condition-bookkeeping-on-every-association-scope).
