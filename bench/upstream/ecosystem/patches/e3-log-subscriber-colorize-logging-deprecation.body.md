### Deprecate ActiveSupport::LogSubscriber.colorize_logging

Through 8.1, `ActiveSupport::LogSubscriber` declared `mattr_accessor :colorize_logging`. aebcb61520 moved color logging into `ActiveSupport::ColorizeLogging` and the setting to `ActiveSupport.colorize_logging`. The instance reader survived, but the class-level reader and writer went away without a deprecation.

Gems still call it. awesome_print 1.9.2, the latest stable release, runs this when it loads:

```ruby
AwesomePrint.force_colors! ActiveSupport::LogSubscriber.colorize_logging
```

On main that raises `NoMethodError` inside `Bundler.require`, so apps that load awesome_print fail to boot. administrate's example app is one.

| administrate example app | 8-1-stable | main | this PR |
|---|---|---|---|
| boots with awesome_print 1.9.2 | yes | NoMethodError | yes, one deprecation warning |

This brings back `LogSubscriber.colorize_logging` and `colorize_logging=` as deprecated methods that delegate to `ActiveSupport.colorize_logging`, so the old and new names cannot disagree. They warn and will be removed in Rails 9.0. The test sets the value through each name, reads it back through the other, and restores it.
