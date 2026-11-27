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

This makes backtraces faster again. Under Callgrind, one `caller` on a 150-frame stack takes 1.09M instructions on master and 0.85M with this change, and `Exception#backtrace` 1.10M and 0.86M; repeated runs agree within 0.03%. Ruby 4.0.9 takes 0.86M and 0.87M, so this brings backtraces back to 4.0's cost. I'll try to add a `make benchmark` comparison; on the VM used here, base against itself varied too much to show one.
