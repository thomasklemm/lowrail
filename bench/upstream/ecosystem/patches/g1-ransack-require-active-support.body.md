### Require active_support before its core extensions

On Rails main, `require "ransack"` fails:

```
active_support/descendants_tracker.rb:15:in '<module:DescendantsTracker>': uninitialized constant ActiveSupport::DescendantsTracker::WeakSet (NameError)
```

`lib/ransack.rb` requires `active_support/core_ext` without loading `active_support` first. Rails expects `active_support` to be required before core extensions are loaded on their own; `WeakSet` now lives in its own file and is found through the autoload that `active_support.rb` sets up.

This adds `require 'active_support'` before `require 'active_support/core_ext'`. I first proposed loading `WeakSet` from Rails' side in rails/rails#59623; it was closed because this is the documented contract ([comment](https://github.com/rails/rails/pull/59623#issuecomment-6635608877)), so the fix belongs here.

With the change, the suite loads on Rails main again and passes as before on 8-1-stable and on 8.1.0, the oldest Rails Ransack supports.
