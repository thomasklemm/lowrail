`index_with` runs on almost every request: `IndexedRow`'s column index for every query result, `serializable_hash` for every `as_json`, `attributes_with_values` for every save. It builds its hash with `to_h { [elem, value] }`, so it allocates a pair array per element that `to_h` immediately takes apart. #59108 replaced that with a loop and #59203 reverted it, because on Ruby 4.1 the loop's hash moved to the C heap at the third insert while `to_h` presizes. Since ruby/ruby#19537, `Hash.new(capacity:)` embeds the same way.

On Ruby 4.1 this fills `Hash.new(capacity: size)`, or `{}` for two elements or fewer; Ruby 4.0 and Array subclasses keep `to_h`. The hash is the same, including order, duplicate keys, default and memsize. Boundary: a plain Array with an overridden `each` or `size` is filled through the override on 4.1, as in Rails 8.1; a test documents it.

| Ruby 4.1, objects per call | main | this PR |
| --- | ---: | ---: |
| interpreter | n + 1 | 1 |
| YJIT, n > 2 | n + 1 | 3 (1 with ruby/ruby#19663) |

In instructions it is not faster at small sizes on Ruby master 9aa0898240: in the interpreter +16% at 3 elements and +2.6% for a 4-attribute `serializable_hash`, −13% at 50; under ZJIT +46% at 3 elements, because the saving there depends on [ruby/ruby#19662](https://github.com/ruby/ruby/pull/19662) specializing `Hash.new(capacity:)` (Callgrind, A/A within 0.1%).

On byroot's heap-report harness it removes 12k / 61k / 5k objects per iteration on railsbench / shipit / lobsters, with no spills; Ruby 4.0 is unchanged.

