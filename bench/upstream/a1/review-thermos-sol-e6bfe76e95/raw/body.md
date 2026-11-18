# Don't compare owner conditions when joining an association without a scope

Since #59836, `join_scope` compares the where clauses before and after merging the association's scope items, to
detect owner conditions the scope removed. It does so also when there are no scope items. Comparing predicates can
call into their bind values: `Array#-` hashes both sides once they are large enough, and `QueryAttribute#hash` and
`#==` serialize the value. So joining an association whose target default scope has an out-of-range condition
raises `ActiveModel::RangeError` instead of matching no records:

```ruby
class Child < ActiveRecord::Base
  default_scope { where((0..16).to_h { |i| [:"key#{i}", 1] }.merge(key0: 2**70)) }
end

class Parent < ActiveRecord::Base
  has_many :children
end

Parent.joins(:children).to_a # => ActiveModel::RangeError (Rails 8.1: [])
```

This skips the comparison when there are no scope items, since nothing can have removed a condition.
