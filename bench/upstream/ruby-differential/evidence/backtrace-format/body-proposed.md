Since `location_format` switched to `"%"PRIsVALUE`, every backtrace line goes through `ruby__sfvextra`, which converts, encoding-checks and `StringValueCStr`s the file and method name. That made `Kernel#caller` and `Exception#backtrace` slower than in 4.0, and a backtrace whose file path contains a NUL byte can no longer be built. Such a path gets that far through `eval` with Prism, the default parser; parse.y rejects it earlier:

```ruby
begin
  eval("raise 'boom'", nil, "a\0b.rb")
rescue => e
  p e.backtrace[0].sub("\0", "<NUL>")
end
# 4.0.9:  "a:1:in '<main>'"
# master: string contains null byte (ArgumentError) from Exception#backtrace
# this:   "a<NUL>b.rb:1:in '<main>'"
```

This appends both strings by their length instead, choosing the encoding the same way `ruby__sfvextra` does, so it still doesn't depend on NUL termination. The output is unchanged for other paths and names.

This makes backtraces faster again. Under Callgrind, one `caller` on a 150-frame stack takes 1.09M instructions on master and 0.85M with this change, and `Exception#backtrace` 1.10M and 0.86M; repeated runs agree within 0.03%.

`make benchmark ITEM=vm_backtrace_to_s` with the included benchmark, one representative run:

```
compare-ruby: ruby 4.1.0dev (2026-11-27T13:11:57Z HEAD 274cfe719a) +PRISM [x86_64-linux]
built-ruby: ruby 4.1.0dev (2026-11-27T17:45:37Z HEAD 5fc1871eec) +PRISM [x86_64-linux]
# Iteration per second (i/s)

|                   |compare-ruby|built-ruby|
|:------------------|-----------:|---------:|
|vm_backtrace_to_s  |     44.957k|   54.089k|
|                   |           -|     1.20x|
```

Across 10 runs this change measured 1.18x–1.23x, while base against itself measured 1.00x–1.06x. Ruby 4.0.9 runs this benchmark at about the same speed as this change. With `--zjit` or `--yjit`, `caller`, `Exception#backtrace` and `Location#to_s` 50 frames deep take about 18–19% less time than on master.
