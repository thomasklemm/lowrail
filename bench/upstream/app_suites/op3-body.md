### Restore the private `validation_context=` writer

#58220 removed the private `ActiveModel::Validations#validation_context=` as unused inside Rails. Released code calls it to set or clear the context around validations it runs itself, and now raises `NoMethodError` on main:

* [ancestry 5.1.0's `sane_ancestor_ids?`](https://github.com/stefankroes/ancestry/blob/c03bc1a9b0339236f4e817ebd9730cc62d46c453/lib/ancestry/instance_methods.rb#L146), which [runs whenever a saved node's parent changes](https://github.com/stefankroes/ancestry/blob/c03bc1a9b0339236f4e817ebd9730cc62d46c453/lib/ancestry/instance_methods.rb#L40) and in `check_ancestry_integrity!`;
* [OpenProject's `ModelContract#contract_valid?`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/app/contracts/model_contract.rb#L100), the base of its contracts, so most of its create and update services fail.

```ruby
node.update!(parent: other) # ancestry 5.1.0
# 8.1: saved; main: NoMethodError: undefined method 'validation_context='
```

ancestry has open PRs (stefankroes/ancestry#769, stefankroes/ancestry#770) that stop calling it, but its maintainer [said](https://github.com/stefankroes/ancestry/pull/770#issuecomment-5752596602) the context is still needed. There is no public way to run validations in a context without `valid?` clearing the errors.

This brings back the three-line private method unchanged, with a test that runs validations in a context set through it.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md#openproject), part of my research project Lowrail).</sub>
