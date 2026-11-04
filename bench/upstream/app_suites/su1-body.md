### Allow anonymous subclasses of cache stores with LocalCache

#58061 moved the computation of `LocalCache`'s registry key into `initialize`, so that the key exists before a ractorized app freezes `Rails.cache`. [The key is built](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/activesupport/lib/active_support/cache/strategy/local_cache.rb#L70) from `self.class.name.underscore`, and `name` is nil for an anonymous class, so creating such a store now raises:

```ruby
Class.new(ActiveSupport::Cache::MemoryStore).new
# => NoMethodError: undefined method 'underscore' for nil
```

On 8.1, the store could be created and used, and only `with_local_cache` raised the same error. Sure's [`TransactionsControllerTest`](https://github.com/we-promise/sure/blob/e658686d5ba7a55734ae9f42683618aa42342b74/test/controllers/transactions_controller_test.rb#L1799) (main) builds such a store to record the keys written during a request.

This uses `name.to_s`, so an anonymous store gets a key such as `:_local_cache_1234`. The key stays unique because of the object id, and named stores keep their keys. The new test covers creating the store and using the local cache, which also fixes the 8.1 `with_local_cache` error.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
