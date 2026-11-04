### Call a custom resolver's _find_all again

Since #58279, [`Resolver#find_all`](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/actionview/lib/action_view/template/resolver.rb#L68-L70) calls `find_templates` directly, so a subclass that overrides the private `_find_all` is no longer called. If it doesn't define `find_templates` too, every lookup raises `NotImplementedError`. `_find_all` is private, but custom resolvers use it, and the removal is unreleased:

- Chatwoot's [`EmailTemplates::DbResolverService`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/email_templates/db_resolver_service.rb#L28) (develop) calls `_find_all` from its own `find_all`; 121 of its mailer specs fail on main.
- view_component-cache_digest's [`Resolver`](https://github.com/tildeio/view_component-cache_digest/blob/82da53b3b092a256841858ed6a482ae0bd80b385/lib/view_component/cache_digest/resolver.rb#L10) (main) overrides it.

This restores the hook in `Resolver`: `find_all` calls `_find_all`, whose default calls `find_templates`. `Resolver#find` still goes through `find_all`, so overriding either keeps working. The tests render through a subclass that overrides `_find_all` and one that implements `find_templates`.

`FileSystemResolver` keeps its own optimized `find` and `find_all`, which never called `_find_all` after #58279. So its subclasses that override `_find_all`, such as [godmin 2.3.0](https://github.com/varvet/godmin/blob/b270f3736dde6022b71544c1692cafea42d4b35f/lib/godmin/resolver.rb#L22) and [rbexy 2.0.0.rc7](https://github.com/patbenatar/rbexy/blob/681bc8813f9e8258b8c8ed4056030d0516d5d4ad/lib/rbexy/rails/component_template_resolver.rb#L13), are not covered here.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
