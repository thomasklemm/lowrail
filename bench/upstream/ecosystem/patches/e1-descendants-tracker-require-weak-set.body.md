> **Superseded.** Opened as rails/rails#59623 and closed unmerged by skipkayhil: Rails expects `active_support` to be required before core extensions. The fix moved to ransack: [g1-ransack-require-active-support](g1-ransack-require-active-support.body.md).

### Require ActiveSupport::WeakSet where DescendantsTracker uses it

3c77803ec0 moved `WeakSet` out of `descendants_tracker.rb` into `active_support/weak_set.rb`, which is registered for autoload in `active_support.rb` but no longer loaded by `descendants_tracker.rb`. So requiring a core extension that loads the tracker before (or without) `active_support` now raises:

```
$ ruby -Iactivesupport/lib -e 'require "active_support/core_ext/class/subclasses"'
descendants_tracker.rb:15: uninitialized constant ActiveSupport::DescendantsTracker::WeakSet (NameError)
```

This works on 8-1-stable. Released ransack hits it: its `lib/ransack.rb` requires `active_support/core_ext` early, and on main none of its specs load.

This requires the file where the constant is used, as other Active Support files do. With it, ransack's suite loads again on main. Like earlier missing-require fixes (b4379f0180, 3b3a43eb09), there is no test: the test helper loads `active_support` first, so a test would need a subprocess.
