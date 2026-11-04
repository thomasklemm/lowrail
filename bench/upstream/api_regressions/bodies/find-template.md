Title: **Restore ActionView::LookupContext#find_template**

This restores `lookup_context.find_template` as an alias of `find!`, so it raises `ActionView::MissingTemplate` when nothing matches, as it did in Rails 8.1. #57783 split template lookup into a non-raising `find` and a raising `find!` and dropped the `find_template` alias. The removal is unreleased.

Gems call it directly, and on main they raise `NoMethodError` the first time they look up a template:

| Gem | Call |
| --- | --- |
| jpmobile | `lookup_context.find_template(options[:template], options[:prefixes])` |
| rabl-rails | `view.lookup_context.find_template(path, [], false)` |
| thredded | `@lookup_context.find_template(partial, [], true, locals.keys, {})` |

props_template already checks `respond_to?(:find!)`, so it works with both names.

Found, missing, partial, option-hash and locale lookups return the same as on 8-1-stable. The new test fails without the alias, and also when the alias points at the non-raising `find`.
