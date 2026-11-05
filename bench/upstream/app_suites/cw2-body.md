### Call a custom resolver's _find_all again

Since #58279, [`Resolver#find_all`](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/actionview/lib/action_view/template/resolver.rb#L68-L70) calls `find_templates` directly, so private `_find_all` overrides on direct `Resolver` subclasses are bypassed; without `find_templates`, every lookup raises `NotImplementedError`. `_find_all` is private, but custom resolvers use it, and the removal is unreleased:

- Chatwoot's [`EmailTemplates::DbResolverService`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/email_templates/db_resolver_service.rb#L28) (develop) overrides `find_all` and calls the inherited `_find_all`, which no longer exists. 121 of its mailer specs fail on main with `NoMethodError`, and pass with this change alone.
- view_component-cache_digest's [`Resolver`](https://github.com/tildeio/view_component-cache_digest/blob/82da53b3b092a256841858ed6a482ae0bd80b385/lib/view_component/cache_digest/resolver.rb#L10) (main) overrides `_find_all`, which is now bypassed.

This restores the hook in `Resolver`: `find_all` passes its six arguments to `_find_all`, whose default calls `find_templates`. `Resolver#find` still goes through `find_all`, so overrides of `find_all`, `_find_all` and `find_templates` all keep working. The tests cover each of the three shapes and the arguments `_find_all` receives.

`FileSystemResolver` keeps its own optimized `find` and `find_all`, which don't call `_find_all`, so its subclasses' overrides, such as [godmin 2.3.0](https://github.com/varvet/godmin/blob/b270f3736dde6022b71544c1692cafea42d4b35f/lib/godmin/resolver.rb#L22) and [rbexy 2.0.0.rc7](https://github.com/patbenatar/rbexy/blob/681bc8813f9e8258b8c8ed4056030d0516d5d4ad/lib/rbexy/rails/component_template_resolver.rb#L13), are not covered. Honoring them there would need a check on every `find`, so it's left out to keep #58279's fast path.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
