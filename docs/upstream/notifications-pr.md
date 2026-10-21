# PR draft: Skip empty group mapping when building notification handles

### Motivation / Background

Direct notification instrumenters, including Active Record's SQL and
transaction instrumentation, build a handle even when no active subscriber
matches. `Fanout#build_handle` maps the empty grouping to an empty Array and
then returns `NullHandle`.

### Detail

Check whether the live result of `groups_for(name)` is empty before mapping
it. Nonempty groups still instantiate the same groups and Handle in the same
order. Empty groups return the existing `NullHandle` without the mapping.

`groups_for` still runs on every invocation, including its live `silenced?`
checks. Subscriptions, unsubscriptions and silence changes are not cached or
short-circuited. This is a small follow-up to #59095, which removed a different
array in `groups_for`, not in `build_handle`. The existing top-level
`Notifications.instrument` listening check is unchanged.

### Benchmark

Ruby 4.0.7, x86_64 Linux, Rails main at
`6e8d3903f85dd948d726bee9495ea77bc8e50aaa`, benchmark-ips 2.15.1. One cycle is
`build_handle` / `start` / `finish`, with a reused payload, warmed subscription
caches and no subscriber work. One second warmup and three seconds measurement
per scenario, separate before/after processes. Allocated objects are counted
over 20,000 warmed cycles with GC enabled.
No dependency installs or test suites ran alongside these measurements.

| Subscribers | Objects before → after | Interpreter i/s before → after | YJIT i/s before → after |
|---|---:|---:|---:|
| None | 2 → 0 | 2.711M ±4.4% → 4.301M ±0.7% | 4.373M ±4.6% → 10.742M ±2.6% |
| One silenced | 2 → 0 | 1.802M ±1.9% → 2.407M ±1.8% | 3.149M ±2.1% → 5.584M ±2.3% |
| One timed | 7 → 7 | 505.861k ±8.0% → 505.695k ±2.0% | 845.673k ±0.9% → 895.193k ±5.5% |
| One monotonic | 5 → 5 | 560.045k ±3.8% → 557.119k ±2.7% | 959.183k ±1.4% → 966.873k ±2.2% |
| One Event-object | 6 → 6 | 299.611k ±5.0% → 279.397k ±6.2% | 503.808k ±6.5% → 503.481k ±3.1% |
| Silenced + timed | 7 → 7 | 477.779k ±3.9% → 463.933k ±2.7% | 810.768k ±2.6% → 839.447k ±5.6% |

No-subscriber throughput is 1.59× interpreter / 2.46× YJIT, and fully silenced
throughput is 1.34× / 1.77×, in this microbenchmark. All active-only and mixed
comparisons fall within benchmark-ips's reported error, including the lower
Event-object interpreter point estimate. Active-case allocations are
unchanged. No request-level improvement is claimed.

Save the following as `notifications_bench.rb`. Install `benchmark-ips` and
the checkout's runtime dependencies. Run against two checkouts with the same
output prefix to compare the saved baseline:

```sh
ruby notifications_bench.rb /path/to/rails-before before /tmp/notifications-interpreter
ruby notifications_bench.rb /path/to/rails-after after /tmp/notifications-interpreter
ruby --yjit notifications_bench.rb /path/to/rails-before before /tmp/notifications-yjit
ruby --yjit notifications_bench.rb /path/to/rails-after after /tmp/notifications-yjit
```

```ruby
# frozen_string_literal: true

rails, label, output = ARGV
abort "usage: #{$0} RAILS_CHECKOUT LABEL OUTPUT_PREFIX" unless output
$LOAD_PATH.unshift File.join(rails, "activesupport/lib")
require "active_support"
require "active_support/notifications"
require "benchmark/ips"

puts RUBY_DESCRIPTION
puts "Rails #{ActiveSupport::VERSION::STRING}; benchmark-ips #{Benchmark::IPS::VERSION}"
puts "checkout: #{rails}; label: #{label}"

class SilenceableSubscriber
  def start(*)
  end

  def finish(*)
  end

  def silenced?(name)
    true
  end
end

%i[empty silenced timed monotonic event_object mixed].each do |name|
  fanout = ActiveSupport::Notifications::Fanout.new
  fanout.subscribe("bench", SilenceableSubscriber.new) if [:silenced, :mixed].include?(name)
  fanout.subscribe("bench") { |*args| } if [:timed, :mixed].include?(name)
  fanout.subscribe("bench", monotonic: true) { |*args| } if name == :monotonic
  fanout.subscribe("bench") { |event| } if name == :event_object
  payload = {}
  operation = -> do
    handle = fanout.build_handle("bench", "id", payload)
    handle.start
    handle.finish
  end
  1_000.times { operation.call }
  GC.start
  before = GC.stat(:total_allocated_objects)
  20_000.times { operation.call }
  allocated = GC.stat(:total_allocated_objects) - before
  puts "#{name}: #{format('%.3f', allocated.fdiv(20_000))} objects/cycle"

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
controls exercise empty → regexp subscription → unsilence → silence →
unsubscribe, payload mutation, a handle held across unsubscribe and a Fanout
subclass overriding `groups_for`.

The branch is based on refreshed main
`0f19d01ab94a6a7d8d5021585aaa9a3a9a39e3f5`; the Active Support sources are
unchanged by that main update. With the independent CurrentAttributes
iteration fix also applied, all relevant component suites pass:

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
