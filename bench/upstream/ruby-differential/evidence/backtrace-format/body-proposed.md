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

This makes backtraces faster again. Under Callgrind, one `caller` on a 150-frame stack takes 1.09M instructions on master, 0.85M with this change and 0.86M on Ruby 4.0.9 (`Exception#backtrace`: 1.10M, 0.86M and 0.87M), with repeated runs within 0.03%. With the included `benchmark/vm_backtrace_to_s.yml`, `make benchmark` showed 1.19x–1.21x over master in 5 of 7 runs, but on a noisy 2-vCPU VM where master against itself ranged from 1.00x to 1.16x, so treat that only as a rough sign.
