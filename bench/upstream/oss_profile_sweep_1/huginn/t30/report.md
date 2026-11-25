# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec --exclude-pattern spec/features/**/*_spec.rb --format documentation`
* Ruby: ruby 3.4.13 (2026-11-19 revision 48857d6f2e) +PRISM [x86_64-linux]
* Rails: 8.1.4.1, test environment
* Counted in run 1: 10 jobs; 1 run
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 0 | 0.0 | 10 | 0 | 0 | 0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | AgentReceiveJob#perform | 9 | 7113.1 |  | 7030.3 |  |  |
| 2 | AgentCheckJob#perform | 1 | – |  | 2962.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | 174.7 | 100% |  | `type_map.fetch(oid, fmod, sql_type) {` |
| 2 | `RAILS/activesupport/lib/active_support/descendants_tracker.rb:108` | 97.8 | 100% |  | `subclasses = DescendantsTracker.reject!(self.subclasses)` |
| 3 | `RAILS/activesupport/lib/active_support/descendants_tracker.rb:109` | 97.8 | 100% |  | `subclasses.concat(subclasses.flat_map(&:descendants))` |
| 4 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | 93.6 | 100% |  | `WhereClause.new(predicates \| other.predicates)` |
| 5 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` (debug logging) | 91.2 | 100% |  | `"\e[#{modes.join(";")}m" if modes.any?` |
| 6 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` (debug logging) | 70.8 | 100% |  | `binds = binds.inspect` |
| 7 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` (debug logging) | 60.8 | 100% |  | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 8 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | 51.2 | 100% |  | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 9 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | 49.1 | 100% |  | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 10 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` | 47.7 | 100% |  | `attrs = []` |
