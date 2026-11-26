# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 7115.2 / 7109.8, head 7113.7 / 7112.9.

A change counts when it exceeds the noise floor: twice the larger run-to-run spread in either report and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job, mail.

**Not a gate (exit 0): no A/A pair.** The spread inside one capture misses how much invocations differ, so what this lists is a place to look. Profile the base twice and pass the second with `--aa` to gate.

## Regressions: 2

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | Doorkeeper::ApplicationsController#create | 3395.2 | 4543.0 | +1147.80 | 28.0 |
| job action | HeartbeatImportDumpJob#perform | 1317.25 | 1375.25 | +58.00 | 20.0 |

## Improvements: 5

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | Settings::ProfileController#update_display_name | 104944.25 | 103656.0 | -1288.25 | 438.0 |
| request action | My::HeartbeatImportsController#create | 2219.2 | 2113.2 | -106.00 | 60.4 |
| job line | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` | 9.47 | 4.74 | -4.74 | 1.0 |
| job line | `RAILS/activejob/lib/active_job/log_subscriber.rb:23` | 2.46 | 0.26 | -2.20 | 1.0 |
| job line | `RAILS/activejob/lib/active_job/queue_adapters/test_adapter.rb:43` | 1.21 | 0.11 | -1.10 | 1.0 |

Not compared: 67 actions (67 no warm value).
