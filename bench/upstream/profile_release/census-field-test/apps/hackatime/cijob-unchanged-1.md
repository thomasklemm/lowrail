# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 7115.2 / 7109.8, head 7113.7 / 7112.9.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job, mail.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| job action | HeartbeatImportDumpJob#perform | 1317.25 | 1375.25 | +58.00 | 20.0 |

## Improvements: 3

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| job line | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` | 9.47 | 4.74 | -4.74 | 1.0 |
| job line | `RAILS/activejob/lib/active_job/log_subscriber.rb:23` | 2.46 | 0.26 | -2.20 | 1.0 |
| job line | `RAILS/activejob/lib/active_job/queue_adapters/test_adapter.rb:43` | 1.21 | 0.11 | -1.10 | 1.0 |

Not compared: 69 actions (67 no warm value, 2 no warm value in the A/A report).
