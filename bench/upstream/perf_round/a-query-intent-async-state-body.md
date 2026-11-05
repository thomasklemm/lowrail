### Keep QueryIntent's background session, mutex and lock wait together

`QueryIntent#initialize` presets [`@session`, `@mutex` and `@lock_wait`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/connection_adapters/query_intent.rb#L102-L105), which only an intent scheduled by [`async_schedule!`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/connection_adapters/query_intent.rb#L390-L396) uses. With them every intent has 30 instance variables after `initialize` and 31 once its result is cast. Ruby master no longer has a 320-byte heap (ruby/ruby#16282), so each intent takes a 512-byte slot there.

This moves the three into an `AsyncState` struct that `async_schedule!` creates. Every intent, background ones included, now has 28 or 29 instance variables and fits a 256-byte slot, and foreground and background intents share one shape. `lock_wait` reads through to the struct; the unused `session` reader and writer go away. Behaviour is unchanged: the foreground reads of these fields were already nil-safe.

Heap slot bytes per ruby-bench iteration, Ruby master a041273a4c, fixed heap (main against itself within 0.005%); objects are unchanged:

| | main | this PR |
| --- | ---: | ---: |
| railsbench | 59,087,612 | 58,575,612 (−0.87%) |
| shipit | 52,044,134 | 51,541,077 (−0.97%) |
| lobsters | 33,485,554 | 33,214,774 (−0.81%) |

On Ruby 4.0 an intent stays in a 320-byte slot either way.

---
<sub>Found while checking which Rails objects lost the 320-byte slot on Ruby master ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/perf-round-main.md), part of my research project Lowrail).</sub>
