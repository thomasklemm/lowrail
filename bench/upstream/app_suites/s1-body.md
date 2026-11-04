### Note in the upgrade guide that Rack::Sendfile requires x_sendfile_header

#56915 stopped adding `Rack::Sendfile` to the default middleware stack unless `config.action_dispatch.x_sendfile_header` is configured. Its CHANGELOG entry describes the change, but the upgrade guide doesn't mention what it means for existing apps: code that positions middleware relative to `Rack::Sendfile` now raises on boot. Redmine does this in [`config/application.rb`, line 79](https://github.com/redmine/redmine/blob/41cd39c24a9f913a69c8a9ec4cbc128a6600fbce/config/application.rb#L79) (master, shortened):

```ruby
config.middleware.insert_before Rack::Sendfile, Rack::ContentLength
# => No such middleware to insert before: Rack::Sendfile (RuntimeError)
```

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" that shows two ways forward:

* Configure `x_sendfile_header` to keep sending files through the web server.
* Insert relative to another middleware. The example uses `ActionDispatch::Executor`, which is always in the default stack, and the note points out that it comes after `ActionDispatch::Static`, so the insertion point decides which requests the middleware sees.

Docs only.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
