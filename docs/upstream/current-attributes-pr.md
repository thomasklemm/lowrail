# PR draft: Avoid pair allocations when resolving CurrentAttributes defaults

### Motivation / Background

`CurrentAttributes#resolve_defaults` runs when constructing an instance and on
every reset. `each_with_object` packs each Hash entry into an Array before the
block destructures it, even for attributes without defaults. Those pairs do
not escape or contribute to the resulting attributes.

### Detail

Iterate the live defaults Hash with `each` and accumulate into a fresh local
Hash. This keeps the order, the `NOT_SET` check, nil/false defaults, each
callable invocation and each value's `dup`. Reset callbacks and the
`resolve_defaults` dispatch remain unchanged. No default or result is cached.

This is independent of #57821: it does not remove nil-valued keys or change
the semantics of `set`.

### Benchmark

Ruby 4.0.7, x86_64 Linux, Rails main at
`6e8d3903f85dd948d726bee9495ea77bc8e50aaa`, benchmark-ips 2.15.1. Each row is
one public instance `reset`, with no reset callbacks. One second warmup and
three seconds measurement per scenario in separate before/after processes.
Allocated objects are counted over 20,000 warmed resets with GC enabled.
No dependency installs or test suites ran alongside these measurements.

| Defaults | Objects before → after | Interpreter i/s before → after | YJIT i/s before → after |
|---|---:|---:|---:|
| Empty | 2 → 1 | 1.739M ±0.8% → 2.025M ±0.8% | 4.111M ±7.0% → 5.919M ±13.6% |
| Three unset | 5 → 1 | 934.955k ±2.3% → 1.298M ±9.1% | 1.348M ±0.6% → 2.440M ±9.2% |
| Three scalar (0, false, nil) | 5 → 1 | 496.345k ±2.2% → 598.564k ±7.5% | 633.524k ±5.9% → 877.211k ±2.2% |
| Three mutable | 8 → 4 | 400.144k ±1.1% → 504.867k ±4.4% | 520.566k ±5.0% → 711.969k ±3.1% |
| Three callable | 7 → 3 | 592.269k ±0.9% → 758.132k ±6.4% | 761.489k ±2.3% → 1.003M ±13.0% |
| Ten mixed | 17 → 6 | 206.013k ±2.6% → 268.852k ±1.7% | 244.775k ±2.9% → 308.213k ±3.3% |

The ten-entry mixed case is 1.31× interpreter / 1.26× YJIT throughput in
these exploratory microbenchmark runs. These are single-process-pair point
estimates, not stable speedup guarantees or application request measurements.
The reported ± values are within-run standard deviations, not confidence
intervals for the before/after difference.

Save the following as `current_attributes_bench.rb`. Install `benchmark-ips`
and the checkout's runtime dependencies. Run against two checkouts, using the
same output prefix to compare the saved baseline:

```sh
ruby current_attributes_bench.rb /path/to/rails-before before /tmp/current-interpreter
ruby current_attributes_bench.rb /path/to/rails-after after /tmp/current-interpreter
ruby --yjit current_attributes_bench.rb /path/to/rails-before before /tmp/current-yjit
ruby --yjit current_attributes_bench.rb /path/to/rails-after after /tmp/current-yjit
```

```ruby
# frozen_string_literal: true

rails, label, output = ARGV
abort "usage: #{$0} RAILS_CHECKOUT LABEL OUTPUT_PREFIX" unless output
$LOAD_PATH.unshift File.join(rails, "activesupport/lib")
require "active_support"
require "active_support/current_attributes"
require "benchmark/ips"

puts RUBY_DESCRIPTION
puts "Rails #{ActiveSupport::VERSION::STRING}; benchmark-ips #{Benchmark::IPS::VERSION}"
puts "checkout: #{rails}; label: #{label}"

scenarios = {
  empty: {},
  unset: { user: ActiveSupport::CurrentAttributes::NOT_SET, account: ActiveSupport::CurrentAttributes::NOT_SET, request: ActiveSupport::CurrentAttributes::NOT_SET },
  scalar: { count: 0, enabled: false, missing: nil },
  mutable: { text: "hello", list: [], options: {} },
  callable: { count: -> { 1 }, list: -> { [] }, options: -> { {} } },
  mixed: { user: ActiveSupport::CurrentAttributes::NOT_SET, account: ActiveSupport::CurrentAttributes::NOT_SET,
    count: 0, enabled: false, missing: nil, text: "hello", list: [], options: {}, computed: -> { [] }, another: -> { {} } }
}

scenarios.each do |name, defaults|
  klass = Class.new(ActiveSupport::CurrentAttributes)
  klass.define_singleton_method(:name) { "BenchCurrent#{name}" }
  defaults.each { |key, value| klass.attribute(key, default: value) }
  current = klass.new
  operation = -> { current.reset }
  1_000.times { operation.call }
  GC.start
  before = GC.stat(:total_allocated_objects)
  20_000.times { operation.call }
  allocated = GC.stat(:total_allocated_objects) - before
  puts "#{name}: #{format('%.3f', allocated.fdiv(20_000))} objects/reset"

  Benchmark.ips do |x|
    x.config(warmup: 1, time: 3)
    x.report(label, &operation)
    x.compare!(order: :baseline)
    x.save!("#{output}-#{name}.json")
  end
end
```

### Verification

The complete Active Support suite passes on this branch: **6,827 tests /
26,697 assertions**, no failures/errors, 60 conditional skips. Existing
tests are unchanged for this implementation-only refactor. Additional
controls check live and mid-iteration default changes, fresh mutable values,
nil/false/unset membership, callable replacement, callback order, prepend
overrides and String/SafeBuffer encoding and safety.

The branch is based on refreshed main
`0f19d01ab94a6a7d8d5021585aaa9a3a9a39e3f5`; the Active Support sources are
unchanged by that main update. With the independent notification-handle
allocation fix also applied, all relevant component suites pass:

- Active Support: 6,827 / 26,697; 60 skips.
- Action View's three groups: 2,901 / 6,865; 249 / 338; 173 / 334; no skips.
- Active Record SQLite: 10,131 / 36,120; 52 skips.

All have zero failures/errors. Commands, from each component directory:

```sh
# Ruby 4.0.7; install the checkout's test bundle and run local Redis/Memcached.
export BUNDLE_ONLY=default:test:rubocop:cable:db PARALLEL_WORKERS=1 SEED=41231
bundle exec rake test         # activesupport, actionview
bundle exec rake test:sqlite3 # activerecord
```

RuboCop reports no offenses in the changed framework files. Serial tests are
used because two backtrace-cleaner assertions also fail on untouched main
with parallel worker frames; no tests were excluded or assertions changed.
No PostgreSQL/MySQL adapter or hosted-CI result is claimed.
